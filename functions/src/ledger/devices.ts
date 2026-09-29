import {FieldValue} from "firebase-admin/firestore";
import {CallableRequest, onCall} from "firebase-functions/v2/https";
import {z} from "zod";
import {db} from "../common/firebase";
import {OPTS, fail, parse} from "./callable";

// Bildirim anahtarları cihaz başınadır ve tek sahiplidir: bir anahtar bir
// hesaba kaydedilince diğer tüm hesaplardan silinir. Aynı telefonda A çıkış
// yapıp (internetsiz bile olsa) B giriş yapınca A'nın bildirimleri artık o
// telefona gitmez. Bir hesapta en fazla MAX_DEVICES cihaz tutulur; en eski
// düşer. Çıkışta uygulama anahtarı FCM'de iptal eder; iptal edilen anahtara
// giden ilk push hata verir ve anahtar hesaptan silinir (common/push.ts).

export const MAX_DEVICES = 5;

const TokenInput = z.object({token: z.string().min(1).max(4096)}).strict();

/**
 * Oturum, doğrulanmış kimlik ve silinmemiş hesap. Koşul kabulü aranmaz:
 * anahtar, koşullar ekranından önce de kaydedilebilir. Web onayı misafiri
 * anahtar kaydedemez (profil oluşup misafir temizliğini engellemesin).
 * @param {CallableRequest<unknown>} req İstek.
 * @return {Promise<string>} Kullanıcı.
 */
async function requireDeviceOwner(
  req: CallableRequest<unknown>
): Promise<string> {
  if (!req.auth) fail("unauthenticated", "Giriş yapmalısınız.");
  const token = req.auth.token;
  const byPhone = token.firebase?.sign_in_provider === "phone";
  if (token.email_verified !== true && !byPhone) {
    fail("permission-denied",
      "Devam etmek için e-posta adresinizi doğrulamalısınız.");
  }
  const uid = req.auth.uid;
  const [deleted, guest] = await db.getAll(
    db.collection("deletedAccounts").doc(uid),
    db.collection("webGuests").doc(uid),
  );
  if (deleted.exists) fail("permission-denied", "Bu hesap silindi.");
  if (guest.exists) {
    fail("failed-precondition", "Bu oturum anahtar kaydedemez.");
  }
  return uid;
}

/**
 * Anahtarı verilen hesaplar dışındaki herkesten siler (yeni ve eski alan).
 * @param {string} token Anahtar.
 * @param {string | null} keepUid Dokunulmayacak hesap.
 */
export async function detachToken(
  token: string,
  keepUid: string | null
): Promise<void> {
  const [byList, byLegacy] = await Promise.all([
    db.collection("users").where("fcmTokens", "array-contains", token).get(),
    db.collection("users").where("fcmToken", "==", token).get(),
  ]);
  const batch = db.batch();
  let ops = 0;
  for (const doc of byList.docs) {
    if (doc.id === keepUid) continue;
    batch.update(doc.ref, {fcmTokens: FieldValue.arrayRemove(token)});
    ops++;
  }
  for (const doc of byLegacy.docs) {
    if (doc.id === keepUid) continue;
    batch.update(doc.ref, {fcmToken: FieldValue.delete()});
    ops++;
  }
  if (ops > 0) await batch.commit();
}

/** Bu cihazın anahtarını oturumdaki hesaba kaydeder. */
export const registerPushToken = onCall<unknown>(OPTS, async (req) => {
  const uid = await requireDeviceOwner(req);
  const {token} = parse(TokenInput, req.data);
  await detachToken(token, uid);
  const ref = db.collection("users").doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = (snap.get("fcmTokens") as string[] | undefined) ?? [];
    const next = [token, ...current.filter((t) => t !== token)]
      .slice(0, MAX_DEVICES);
    // Eski tek anahtar alanı yeni listeye taşınır.
    tx.set(ref, {fcmTokens: next, fcmToken: FieldValue.delete()},
      {merge: true});
  });
  return {saved: true};
});
