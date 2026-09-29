import {DocumentReference, Transaction} from "firebase-admin/firestore";
import {
  CallableRequest,
  FunctionsErrorCode,
  HttpsError,
} from "firebase-functions/v2/https";
import {z} from "zod";
import {REGION, db} from "../common/firebase";
import {Ledger, Side, otherSide, sideOf, todayIstanbul} from "./model";

// Callable komutların ortak parçaları.
// App Check uygulamalar kaydedilince açılacak (plan §9).
export const OPTS = {region: REGION, enforceAppCheck: false};

export const Id = z.string().regex(/^[A-Za-z0-9_-]{8,128}$/);

/**
 * @param {FunctionsErrorCode} code Hata kodu.
 * @param {string} message Kullanıcıya gösterilebilir mesaj.
 */
export function fail(code: FunctionsErrorCode, message: string): never {
  throw new HttpsError(code, message);
}

/**
 * Oturum açmış ve e-postası doğrulanmış kullanıcı. Doğrulanmamış bir
 * e-postayla (başkasının adresi olabilir) işlem yapılamaz. Telefonla giriş
 * (Faz 2c) e-posta taşımaz; o kimlik SMS ile doğrulanmıştır.
 * Hesabı silinmiş kişinin eski oturumu (belirteç ~1 saat geçerli kalır)
 * hiçbir komut çalıştıramaz; silme başında yazılan işarete bakılır.
 * @param {CallableRequest<unknown>} req İstek.
 * @return {Promise<string>} Oturumdaki kullanıcı.
 */
export async function requireUid(
  req: CallableRequest<unknown>
): Promise<string> {
  if (!req.auth) fail("unauthenticated", "Giriş yapmalısınız.");
  const token = req.auth.token;
  const byPhone = token.firebase?.sign_in_provider === "phone";
  if (token.email_verified !== true && !byPhone) {
    fail("permission-denied",
      "Devam etmek için e-posta adresinizi doğrulamalısınız.");
  }
  if (await isDeletedAccount(req.auth.uid)) {
    fail("permission-denied", "Bu hesap silindi.");
  }
  return req.auth.uid;
}

/**
 * Hesap silme başladı mı (deletedAccounts/{uid}; istemciye kapalı).
 * @param {string} uid Kullanıcı.
 * @return {Promise<boolean>} Silinmiş ya da siliniyorsa true.
 */
export async function isDeletedAccount(uid: string): Promise<boolean> {
  return (await db.collection("deletedAccounts").doc(uid).get()).exists;
}

/**
 * Geri alınamaz işlemler (hesap silme) için: oturum son birkaç dakika içinde
 * açılmış (yeniden giriş yapılmış) olmalı. Kilidi açık unutulmuş telefondan
 * hesap silinemez. E-posta doğrulaması aranmaz; doğrulanmamış hesap da
 * kendini silebilir.
 * @param {CallableRequest<unknown>} req İstek.
 * @param {number} maxAgeSeconds Girişin en fazla kaç saniye önce olduğu.
 * @param {Date} now An.
 * @return {string} Oturumdaki kullanıcı.
 */
export function requireRecentLogin(
  req: CallableRequest<unknown>,
  maxAgeSeconds: number,
  now: Date = new Date()
): string {
  if (!req.auth) fail("unauthenticated", "Giriş yapmalısınız.");
  const authTime = Number(req.auth.token.auth_time ?? 0);
  if (now.getTime() / 1000 - authTime > maxAgeSeconds) {
    fail("failed-precondition",
      "REAUTH_REQUIRED: Güvenlik için yeniden giriş yapmanız gerekiyor.");
  }
  return req.auth.uid;
}

/**
 * Günlük kullanım hakkından bir tane düşer; dolmuşsa reddeder. Spam ve
 * kötüye kullanımı sınırlar (rateLimits istemciye kapalıdır).
 * @param {string} key Sayaç (ör. "entries_<uid>").
 * @param {number} limit Günlük üst sınır.
 * @param {string} message Sınır dolunca gösterilecek mesaj.
 */
export async function consumeDaily(
  key: string,
  limit: number,
  message: string
): Promise<void> {
  const ref = db.collection("rateLimits").doc(key);
  const today = todayIstanbul();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = snap.get("day") === today ? (snap.get("count") as number) : 0;
    if (count >= limit) fail("resource-exhausted", message);
    tx.set(ref, {day: today, count: count + 1});
  });
}

/**
 * @param {z.ZodTypeAny} schema Şema.
 * @param {unknown} data Girdi.
 * @return {unknown} Doğrulanmış girdi.
 */
export function parse<T extends z.ZodTypeAny>(
  schema: T,
  data: unknown
): z.infer<T> {
  const result = schema.safeParse(data);
  if (!result.success) {
    const detail = result.error.issues
      .map((i) => `${i.path.join(".") || "girdi"}: ${i.message}`)
      .join("; ");
    fail("invalid-argument", detail);
  }
  return result.data;
}

/**
 * Karşı taraf bu kişiyi engellediyse yeni kayıt, düzeltme ve hatırlatma
 * gönderilemez. Mesaj engeli açıkça söylemez.
 * @param {Ledger} ledger Defter.
 * @param {Side} side İşlemi yapanın tarafı.
 */
export function assertNotBlocked(ledger: Ledger, side: Side): void {
  if (ledger.blockedBy?.[otherSide(side)]) {
    fail("failed-precondition", "Bu kişiye şu an kayıt gönderilemiyor.");
  }
}

/**
 * Defteri okur; üyelik ve durum kontrolü yapar.
 * @param {Transaction} tx Transaction.
 * @param {DocumentReference} ref Defter.
 * @param {string} uid Kullanıcı.
 * @return {Promise<object>} Defter ve kullanıcının tarafı.
 */
export async function readLedger(
  tx: Transaction,
  ref: DocumentReference,
  uid: string
): Promise<{ledger: Ledger; side: Side}> {
  const snap = await tx.get(ref);
  if (!snap.exists) fail("not-found", "Defter bulunamadı.");
  const ledger = snap.data() as Ledger;
  const side = sideOf(ledger, uid);
  // Olmayan defterle aynı yanıt: başkaları arasında defter olup olmadığı
  // (ilişki) hata kodundan öğrenilemez (kurallardaki ilkeyle aynı).
  if (!side) fail("not-found", "Defter bulunamadı.");
  if (ledger.status !== "active") {
    fail("failed-precondition", "Defter kapalı.");
  }
  return {ledger, side};
}
