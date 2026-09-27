import {Timestamp} from "firebase-admin/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {admin, db, REGION} from "../common/firebase";
import {removeAccount} from "./account";

// Günlük bakım (gizlilik politikasındaki saklama süreleri):
// - E-postası 30 gün içinde doğrulanmamış hesaplar silinir (başkasının
//   adresiyle açılmış olabilir; hiçbir işlem yapamaz ama profil tutar).
// - Bir taraf hesabını sildiği için kapanan ortak defterler, kapanıştan
//   10 yıl sonra tamamen silinir (karşı tarafın nüshası; TBK 146).
// - Silinen hesap işareti (deletedAccounts) de 10 yıl sonra silinir: o
//   kimliği taşıyan son defter de o zamana kadar silinmiş olur.

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

/**
 * Doğrulanmamış eski hesapları siler.
 * @param {Date} now An.
 * @return {Promise<number>} Silinen hesap sayısı.
 */
async function purgeUnverified(now: Date): Promise<number> {
  const cutoff = now.getTime() - UNVERIFIED_DAYS * DAY_MS;
  let removed = 0;
  let pageToken: string | undefined;
  do {
    const page = await admin.auth().listUsers(1000, pageToken);
    for (const user of page.users) {
      const byPassword = user.providerData
        .some((p) => p.providerId === "password");
      const created = Date.parse(user.metadata.creationTime);
      if (!byPassword || user.emailVerified || created > cutoff) continue;
      await removeAccount(user.uid, "unverified");
      removed++;
    }
    pageToken = page.pageToken;
  } while (pageToken);
  return removed;
}

/**
 * Saklama süresi dolan kapalı ortak defterleri siler.
 * @param {Date} now An.
 * @return {Promise<number>} Silinen defter sayısı.
 */
async function purgeClosedLedgers(now: Date): Promise<number> {
  const cutoff = yearsBefore(now, CLOSED_LEDGER_YEARS);
  let removed = 0;
  for (;;) {
    const snap = await db.collection("ledgers")
      .where("status", "==", "closed")
      .where("closedAt", "<", Timestamp.fromDate(cutoff))
      .limit(100)
      .get();
    for (const doc of snap.docs) {
      await db.recursiveDelete(doc.ref);
      removed++;
    }
    if (snap.size < 100) return removed;
  }
}

/**
 * Saklama süresi dolan silme işaretlerini siler.
 * @param {Date} now An.
 * @return {Promise<number>} Silinen işaret sayısı.
 */
async function purgeTombstones(now: Date): Promise<number> {
  const cutoff = yearsBefore(now, CLOSED_LEDGER_YEARS);
  let removed = 0;
  for (;;) {
    const snap = await db.collection("deletedAccounts")
      .where("deletedAt", "<", Timestamp.fromDate(cutoff))
      .limit(400)
      .get();
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    if (snap.size > 0) await batch.commit();
    removed += snap.size;
    if (snap.size < 400) return removed;
  }
}

/**
 * Bakımın tamamı (testlerde saat verilebilir).
 * @param {Date} now An.
 * @return {Promise<object>} Özet.
 */
export async function runMaintenance(
  now: Date
): Promise<{unverified: number; closedLedgers: number; tombstones: number}> {
  const unverified = await purgeUnverified(now);
  const closedLedgers = await purgeClosedLedgers(now);
  const tombstones = await purgeTombstones(now);
  return {unverified, closedLedgers, tombstones};
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
