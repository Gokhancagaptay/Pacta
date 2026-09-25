import {randomInt} from "node:crypto";
import {FieldValue} from "firebase-admin/firestore";
import {onCall} from "firebase-functions/v2/https";
import {z} from "zod";
import {admin, db} from "../common/firebase";
import {OPTS, Id, fail, parse, requireUid} from "./callable";
import {Ledger, todayIstanbul} from "./model";

// Kişi bulma: e-posta, Pacta kodu (QR ve davet linki de bu kodu taşır).
// Kodlar codes/{KOD} altında tutulur; istemciye kapalıdır.

/** Karışan harfler yok: 0/O, 1/I/L. */
const CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
const CODE_LENGTH = 6;
const CODE_RE = new RegExp(`^[${CODE_ALPHABET}]{${CODE_LENGTH}}$`);

/** Kod tahminiyle kullanıcı taramayı zorlaştırır. */
export const DAILY_CODE_LOOKUPS = 30;

/**
 * Kullanıcının yazdığı kodu ya da davet linkini koda çevirir.
 * "k7q-3xm", "https://…/u/K7Q3XM" → "K7Q3XM".
 * @param {string} raw Girdi.
 * @return {string | null} Kod ya da geçersizse null.
 */
export function normalizeCode(raw: string): string | null {
  const fromLink = /\/u\/([A-Za-z0-9-]+)/.exec(raw)?.[1] ?? raw;
  const code = fromLink.toUpperCase().replace(/[^A-Z0-9]/g, "");
  return CODE_RE.test(code) ? code : null;
}

/**
 * @return {string} Rastgele kod.
 */
function randomCode(): string {
  let code = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  }
  return code;
}

/**
 * Günlük kod sorgu hakkından bir tane kullanır.
 * @param {string} uid Kullanıcı.
 */
async function consumeCodeLookup(uid: string): Promise<void> {
  const ref = db.collection("rateLimits").doc(`codes_${uid}`);
  const today = todayIstanbul();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = snap.get("day") === today ? (snap.get("count") as number) : 0;
    if (count >= DAILY_CODE_LOOKUPS) {
      fail("resource-exhausted",
        "Bugün çok fazla kod denendi. Yarın tekrar deneyin.");
    }
    tx.set(ref, {day: today, count: count + 1});
  });
}

/**
 * Pacta kodunun sahibini bulur.
 * @param {string} uid Soran kullanıcı.
 * @param {string} raw Kod ya da davet linki.
 * @return {Promise<string>} Kodun sahibi.
 */
export async function uidForCode(uid: string, raw: string): Promise<string> {
  const code = normalizeCode(raw);
  if (!code) {
    fail("invalid-argument",
      "Pacta kodu 6 karakterdir (ör. K7Q-3XM). Kodu kontrol edin.");
  }
  await consumeCodeLookup(uid);
  const snap = await db.collection("codes").doc(code).get();
  if (!snap.exists) {
    fail("not-found",
      "Bu kodla bir Pacta kullanıcısı bulunamadı. Kodu kontrol edin.");
  }
  return snap.get("uid") as string;
}

/**
 * E-postası doğrulanmış kullanıcıyı bulur; bulunamazsa nedenini söyler.
 * @param {string} email E-posta.
 * @return {Promise<string>} Kullanıcı.
 */
export async function uidForEmail(email: string): Promise<string> {
  let user: admin.auth.UserRecord;
  try {
    user = await admin.auth().getUserByEmail(email.trim().toLowerCase());
  } catch (error) {
    if ((error as {code?: string}).code === "auth/user-not-found") {
      fail("not-found",
        "Bu e-postayla kayıtlı bir Pacta kullanıcısı yok. Adresi kontrol " +
        "edin ya da kişiye davet gönderin.");
    }
    throw error;
  }
  if (!user.emailVerified) {
    fail("failed-precondition",
      "Bu kişi hesabını açmış ama e-posta adresini henüz doğrulamamış. " +
      "Gelen doğrulama e-postasındaki bağlantıya tıklamasını isteyin.");
  }
  return user.uid;
}

/**
 * Giriş e-postası; karşı taraf kişiyi tanısın diye defterde görünür.
 * @param {string} uid Kullanıcı.
 * @return {Promise<string | null>} E-posta.
 */
export async function authEmail(uid: string): Promise<string | null> {
  try {
    return (await admin.auth().getUser(uid)).email ?? null;
  } catch {
    return null;
  }
}

/** Kişinin Pacta kodu; yoksa oluşturulur. */
export const myPactaCode = onCall<unknown>(OPTS, async (req) => {
  const uid = requireUid(req);
  const userRef = db.collection("users").doc(uid);
  const existing = (await userRef.get()).get("pactaCode") as string | undefined;
  if (existing) return {code: existing};

  for (let attempt = 0; attempt < 5; attempt++) {
    const candidate = randomCode();
    const codeRef = db.collection("codes").doc(candidate);
    const code = await db.runTransaction(async (tx) => {
      const [user, taken] = [await tx.get(userRef), await tx.get(codeRef)];
      const current = user.get("pactaCode") as string | undefined;
      if (current) return current;
      if (taken.exists) return null;
      tx.set(codeRef, {uid, createdAt: FieldValue.serverTimestamp()});
      tx.set(userRef, {pactaCode: candidate}, {merge: true});
      return candidate;
    });
    if (code) return {code};
  }
  fail("unavailable", "Kod oluşturulamadı, tekrar deneyin.");
});

/** Koddan kişinin adını gösterir; eklemeden önce onay için. */
export const previewCode = onCall<unknown>(OPTS, async (req) => {
  const uid = requireUid(req);
  const input = z.object({code: z.string().max(200)}).strict();
  const {code} = parse(input, req.data);
  const target = await uidForCode(uid, code);
  const profile = await db.collection("users").doc(target).get();
  const name = (profile.get("adSoyad") as string | undefined)?.trim();
  return {
    self: target === uid,
    displayName: name || "Pacta kullanıcısı",
  };
});

/**
 * Özel defteri (yalnızca sahibinin gördüğü) içindeki kayıtlarla birlikte
 * siler. Ortak defterler silinmez; her iki tarafın kaydıdır.
 */
export const deletePrivateLedger = onCall<unknown>(OPTS, async (req) => {
  const uid = requireUid(req);
  const {ledgerId} = parse(z.object({ledgerId: Id}).strict(), req.data);
  const ref = db.collection("ledgers").doc(ledgerId);
  const snap = await ref.get();
  if (!snap.exists) return {deleted: false};
  const ledger = snap.data() as Ledger;
  if (ledger.sides.a.uid !== uid) {
    fail("permission-denied", "Bu defterin sahibi değilsiniz.");
  }
  if (ledger.mode !== "private") {
    fail("failed-precondition",
      "Ortak defter silinemez; karşı tarafın da kaydıdır. Listenizden " +
      "kaldırabilirsiniz.");
  }
  await db.recursiveDelete(ref);
  return {deleted: true};
});
