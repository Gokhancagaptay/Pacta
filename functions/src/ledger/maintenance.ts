import {QueryDocumentSnapshot, Timestamp} from "firebase-admin/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {admin, db, REGION} from "../common/firebase";
import {removeAccount} from "./account";
import {purgeWebData} from "./web";

// Günlük bakım (gizlilik politikasındaki saklama süreleri):
// - E-postası 30 gün içinde doğrulanmamış hesaplar silinir (başkasının
//   adresiyle açılmış olabilir; hiçbir işlem yapamaz ama profil tutar).
// - Bir taraf hesabını sildiği için kapanan ortak defterler, kapanıştan
//   10 yıl sonra tamamen silinir (karşı tarafın nüshası; TBK 146).
// - Silinen hesap işareti (deletedAccounts) de 10 yıl sonra silinir: o
//   kimliği taşıyan son defter de o zamana kadar silinmiş olur.
// - Yanıtlanmayan web onay istekleri süresi dolduktan 30 gün sonra,
//   yanıt vermeden kalan misafir girişleri bir gün sonra silinir (web.ts).

export const UNVERIFIED_DAYS = 30;
export const CLOSED_LEDGER_YEARS = 10;

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Takvim olarak n yıl öncesi.
 * @param {Date} now An.
 * @param {number} years Yıl.
 * @return {Date} Sınır.
 */
function yearsBefore(now: Date, years: number): Date {
  const cutoff = new Date(now);
  cutoff.setFullYear(cutoff.getFullYear() - years);
  return cutoff;
}

/** Bir aşamanın sonucu: silinen ve silinemeyen kayıt sayısı. */
interface PurgeResult {
  removed: number;
  failed: number;
}

/**
 * Bir kaydı silmeyi dener; hata bütün bakımı durdurmaz (ertesi gün tekrar
 * denenir).
 * @param {string} what Günlükte görünecek kayıt.
 * @param {function} op Silme.
 * @param {PurgeResult} result Sayaç.
 */
async function attempt(
  what: string,
  op: () => Promise<unknown>,
  result: PurgeResult
): Promise<void> {
  try {
    await op();
    result.removed++;
  } catch (error) {
    result.failed++;
    logger.error("[maintenance] Silinemedi", {what, error: String(error)});
  }
}

/**
 * Doğrulanmamış eski hesapları siler.
 * @param {Date} now An.
 * @return {Promise<PurgeResult>} Sonuç.
 */
async function purgeUnverified(now: Date): Promise<PurgeResult> {
  const cutoff = now.getTime() - UNVERIFIED_DAYS * DAY_MS;
  const result = {removed: 0, failed: 0};
  let pageToken: string | undefined;
  do {
    const page = await admin.auth().listUsers(1000, pageToken);
    for (const user of page.users) {
      const byPassword = user.providerData
        .some((p) => p.providerId === "password");
      const created = Date.parse(user.metadata.creationTime);
      if (!byPassword || user.emailVerified || created > cutoff) continue;
      await attempt(`user ${user.uid}`,
        () => removeAccount(user.uid, "unverified"), result);
    }
    pageToken = page.pageToken;
  } while (pageToken);
  return result;
}

/**
 * Saklama süresi dolan kapalı ortak defterleri siler. Sorgu imleçle
 * ilerler: silinemeyen defter aynı sayfayı tekrar getirip döngüye sokmaz.
 * @param {Date} now An.
 * @return {Promise<PurgeResult>} Sonuç.
 */
async function purgeClosedLedgers(now: Date): Promise<PurgeResult> {
  const cutoff = Timestamp.fromDate(yearsBefore(now, CLOSED_LEDGER_YEARS));
  const result = {removed: 0, failed: 0};
  let last: QueryDocumentSnapshot | undefined;
  for (;;) {
    let query = db.collection("ledgers")
      .where("status", "==", "closed")
      .where("closedAt", "<", cutoff)
      .orderBy("closedAt")
      .limit(100);
    if (last) query = query.startAfter(last);
    const snap = await query.get();
    for (const doc of snap.docs) {
      await attempt(`ledger ${doc.id}`, () => db.recursiveDelete(doc.ref),
        result);
    }
    if (snap.size < 100) return result;
    last = snap.docs[snap.docs.length - 1];
  }
}

/**
 * Saklama süresi dolan silme işaretlerini siler.
 * @param {Date} now An.
 * @return {Promise<PurgeResult>} Sonuç.
 */
async function purgeTombstones(now: Date): Promise<PurgeResult> {
  const cutoff = Timestamp.fromDate(yearsBefore(now, CLOSED_LEDGER_YEARS));
  const result = {removed: 0, failed: 0};
  let last: QueryDocumentSnapshot | undefined;
  for (;;) {
    let query = db.collection("deletedAccounts")
      .where("deletedAt", "<", cutoff)
      .orderBy("deletedAt")
      .limit(400);
    if (last) query = query.startAfter(last);
    const snap = await query.get();
    if (snap.size > 0) {
      const batch = db.batch();
      snap.docs.forEach((doc) => batch.delete(doc.ref));
      try {
        await batch.commit();
        result.removed += snap.size;
      } catch (error) {
        result.failed += snap.size;
        logger.error("[maintenance] Silme işaretleri silinemedi",
          {error: String(error)});
      }
    }
    if (snap.size < 400) return result;
    last = snap.docs[snap.docs.length - 1];
  }
}

/**
 * Bakımın tamamı (testlerde saat verilebilir). Aşamalar birbirinden
 * bağımsızdır: biri hata verse de diğerleri çalışır.
 * @param {Date} now An.
 * @return {Promise<object>} Silinen sayıları ve silinemeyenler.
 */
export async function runMaintenance(now: Date): Promise<{
  unverified: number;
  closedLedgers: number;
  tombstones: number;
  web: number;
  failed: number;
}> {
  const stage = async (
    name: string,
    run: (now: Date) => Promise<PurgeResult>
  ): Promise<PurgeResult> => {
    try {
      return await run(now);
    } catch (error) {
      logger.error("[maintenance] Aşama yarıda kaldı",
        {stage: name, error: String(error)});
      return {removed: 0, failed: 1};
    }
  };
  const unverified = await stage("unverified", purgeUnverified);
  const closed = await stage("closedLedgers", purgeClosedLedgers);
  const tombstones = await stage("tombstones", purgeTombstones);
  const web = await stage("web", async (at) => {
    const {requests, guests} = await purgeWebData(at);
    return {removed: requests + guests, failed: 0};
  });
  return {
    unverified: unverified.removed,
    closedLedgers: closed.removed,
    tombstones: tombstones.removed,
    web: web.removed,
    failed: unverified.failed + closed.failed + tombstones.failed + web.failed,
  };
}

export const dailyMaintenance = onSchedule(
  {
    schedule: "every day 04:00",
    timeZone: "Europe/Istanbul",
    region: REGION,
    timeoutSeconds: 540,
  },
  async () => {
    const summary = await runMaintenance(new Date());
    logger.info("[maintenance] Günlük bakım", summary);
  }
);
