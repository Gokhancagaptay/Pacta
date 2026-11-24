import {
  Query,
  QueryDocumentSnapshot,
  Timestamp,
} from "firebase-admin/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {admin, db, REGION} from "../common/firebase";
import {RemovalReason, removeAccount} from "./account";
import {AuditProblem, auditStoredLedger} from "./audit";
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
// - Uygulama içi bildirimler (users/{uid}/notifications) 90 gün sonra
//   silinir. Bildirim yalnızca bir haberdir: kayıt, onay ve geçmiş
//   defterde, onay bekleyenler gelen kutusunda (inbox) kalır.
// - Son çalışmadan bu yana değişen defterler bakiye ve zincir
//   tutarlılığı için denetlenir (audit.ts). Salt okunurdur; sorunlar
//   "[audit]" önekiyle hata günlüğüne yazılır, hiçbir şey onarılmaz.

export const UNVERIFIED_DAYS = 30;
export const CLOSED_LEDGER_YEARS = 10;
export const NOTIFICATION_DAYS = 90;

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
      // Telefonla doğrulanmış hesap (Faz 2c) e-postası doğrulanmasa da
      // doğrulanmış sayılır (callable.ts, contacts.ts ile aynı).
      const byPhone = user.providerData.some((p) => p.providerId === "phone");
      const created = Date.parse(user.metadata.creationTime);
      if (!byPassword || byPhone || user.emailVerified || created > cutoff) {
        continue;
      }
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

/** Yarıda kalan silme bu kadar sonra yeniden denenir. */
const RESUME_AFTER_MS = 60 * 60 * 1000;

/**
 * Yarıda kalmış hesap silmelerini tamamlar: silme işareti yazılmış ama
 * işlem (zaman aşımı, hata) bitmemiş; kişi kilitli, verisi ve giriş hesabı
 * duruyor.
 * @param {Date} now An.
 * @return {Promise<PurgeResult>} Sonuç.
 */
async function resumeDeletions(now: Date): Promise<PurgeResult> {
  const result = {removed: 0, failed: 0};
  const snap = await db.collection("deletedAccounts")
    .where("pending", "==", true)
    .limit(50)
    .get();
  for (const doc of snap.docs) {
    const at = (doc.get("deletedAt") as Timestamp | undefined)?.toMillis() ?? 0;
    if (now.getTime() - at < RESUME_AFTER_MS) continue;
    const reason = (doc.get("reason") as RemovalReason | undefined) ?? "user";
    await attempt(`deletion ${doc.id}`,
      () => removeAccount(doc.id, reason), result);
  }
  return result;
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

/** Kullanıcı bildirimi: users/{uid}/notifications/{id}. */
const USER_NOTIFICATION = /^users\/[^/]+\/notifications\/[^/]+$/;

/**
 * Saklama süresi dolan uygulama içi bildirimleri siler. Koleksiyon grubu
 * sorgusu v1'in kök "notifications" koleksiyonunu da getirir; onlar
 * atlanır (ayrı, onaylı bir temizlikle ele alınacak). Atlanan ve
 * silinemeyen belgeler yüzünden aynı sayfa dönmesin diye sorgu imleçle
 * ilerler (deleteQuery bu yüzden kullanılmaz). Dizin:
 * firestore.indexes.json, notifications.createdAt (COLLECTION_GROUP).
 * @param {Date} now An.
 * @return {Promise<PurgeResult>} Sonuç.
 */
async function purgeNotifications(now: Date): Promise<PurgeResult> {
  const cutoff =
    Timestamp.fromMillis(now.getTime() - NOTIFICATION_DAYS * DAY_MS);
  const result = {removed: 0, failed: 0};
  let last: QueryDocumentSnapshot | undefined;
  for (;;) {
    let query = db.collectionGroup("notifications")
      .where("createdAt", "<", cutoff)
      .orderBy("createdAt")
      .limit(400);
    if (last) query = query.startAfter(last);
    const snap = await query.get();
    const own = snap.docs.filter((d) => USER_NOTIFICATION.test(d.ref.path));
    if (own.length > 0) {
      const batch = db.batch();
      own.forEach((doc) => batch.delete(doc.ref));
      try {
        await batch.commit();
        result.removed += own.length;
      } catch (error) {
        result.failed += own.length;
        logger.error("[maintenance] Bildirimler silinemedi",
          {error: String(error)});
      }
    }
    if (snap.size < 400) return result;
    last = snap.docs[snap.docs.length - 1];
  }
}

/**
 * Gece denetiminin sınırları (maliyet üst sınırı). Testlerde
 * değiştirilebilsin diye nesnedir.
 * - windowHours: son bu kadar saatte değişen defterler denetlenir. Bakım
 *   günde bir çalışır; pencere biraz uzun tutulur, iki çalışma arasında
 *   değişen defter kaçmaz.
 * - ledgers: bir gecede denetlenen en fazla defter. Aşılırsa kalanlar o
 *   gece denetlenmez (sayısı günlüğe ve özete yazılır); defter yeniden
 *   değişince tekrar pencereye girer.
 * - entriesPerLedger: bundan fazla kaydı olan defter atlanır (kısmi
 *   denetim yanlış alarm verir); yönetici betiği daha yüksek sınırla
 *   denetleyebilir.
 * - entries: bir gecede okunan en fazla kayıt; aşılınca kalan defterler
 *   atlanır.
 */
export const auditLimits = {
  windowHours: 26,
  ledgers: 500,
  entriesPerLedger: 2000,
  entries: 50000,
};

/** Bir defter için günlüğe yazılan en fazla sorun. */
const LOGGED_PROBLEMS = 50;

const AUDIT_PAGE = 100;

/** Denetim aşamasının sonucu. */
interface AuditResult {
  audited: number;
  problems: number;
  skipped: number;
  failed: number;
}

/**
 * Günlüğe yalnızca kod ve kimlikler gider; uyuşmayan sayılar için yönetici
 * betiği (scripts/auditLedgers.js) çalıştırılır.
 * @param {AuditProblem} p Sorun.
 * @return {object} Günlük satırı.
 */
function forLog(p: AuditProblem) {
  const {code, entryId, relatedEntryId, asset, field, seq, seqTo} = p;
  return Object.fromEntries(
    Object.entries({code, entryId, relatedEntryId, asset, field, seq, seqTo})
      .filter(([, v]) => v !== undefined));
}

/**
 * Son pencerede değişen defterleri denetler (salt okunur). Defter başına
 * hata diğer defterleri durdurmaz.
 * @param {Date} now An.
 * @return {Promise<AuditResult>} Sonuç.
 */
async function auditRecentLedgers(now: Date): Promise<AuditResult> {
  const since = Timestamp.fromMillis(
    now.getTime() - auditLimits.windowHours * 60 * 60 * 1000);
  // Tek alanlı aralık ve sıralama: otomatik dizin yeterli.
  const recent = db.collection("ledgers")
    .where("updatedAt", ">=", since)
    .orderBy("updatedAt");
  const result: AuditResult = {audited: 0, problems: 0, skipped: 0, failed: 0};
  let entriesRead = 0;
  let seen = 0;
  let last: QueryDocumentSnapshot | undefined;
  for (;;) {
    let page = recent.select("updatedAt").limit(AUDIT_PAGE);
    if (last) page = page.startAfter(last);
    const snap = await page.get();
    for (const doc of snap.docs) {
      if (seen >= auditLimits.ledgers || entriesRead >= auditLimits.entries) {
        result.skipped += await countAfter(recent, last);
        logger.warn("[audit] Gece sınırına ulaşıldı; kalan defterler " +
          "denetlenmedi", {skipped: result.skipped, seen, entriesRead,
          limits: auditLimits});
        return result;
      }
      seen++;
      last = doc;
      try {
        const res = await auditStoredLedger(doc.id,
          auditLimits.entriesPerLedger);
        if (res.status === "missing") continue;
        entriesRead += res.entriesRead;
        if (res.status === "tooLarge") {
          result.skipped++;
          logger.warn("[audit] Defterin kaydı çok; atlandı",
            {ledgerId: doc.id, limit: auditLimits.entriesPerLedger});
          continue;
        }
        result.audited++;
        if (res.problems.length > 0) {
          result.problems += res.problems.length;
          logger.error("[audit] Defterde tutarsızlık", {
            ledgerId: doc.id,
            count: res.problems.length,
            problems: res.problems.slice(0, LOGGED_PROBLEMS).map(forLog),
          });
        }
      } catch (error) {
        result.failed++;
        logger.error("[audit] Defter denetlenemedi",
          {ledgerId: doc.id, error: String(error)});
      }
    }
    if (snap.size < AUDIT_PAGE) return result;
  }
}

/**
 * Sınıra takılıp denetlenmeyen defter sayısı (yalnızca rapor için).
 * @param {Query} recent Penceredeki defterler.
 * @param {QueryDocumentSnapshot | undefined} last Son ele alınan defter.
 * @return {Promise<number>} Sayı; sayılamazsa 0.
 */
async function countAfter(
  recent: Query,
  last: QueryDocumentSnapshot | undefined
): Promise<number> {
  try {
    const rest = last ? recent.startAfter(last) : recent;
    return (await rest.count().get()).data().count;
  } catch (error) {
    logger.error("[audit] Kalan defterler sayılamadı",
      {error: String(error)});
    return 0;
  }
}

/**
 * Bakımın tamamı (testlerde saat verilebilir). Aşamalar birbirinden
 * bağımsızdır: biri hata verse de diğerleri çalışır.
 * @param {Date} now An.
 * @return {Promise<object>} Silinen sayıları, denetim sonucu ve
 *     yarıda kalanlar.
 */
export async function runMaintenance(now: Date): Promise<{
  unverified: number;
  closedLedgers: number;
  tombstones: number;
  web: number;
  notifications: number;
  resumed: number;
  audited: number;
  auditProblems: number;
  auditSkipped: number;
  failed: number;
}> {
  const stage = async <T extends {failed: number}>(
    name: string,
    run: (now: Date) => Promise<T>,
    empty: T
  ): Promise<T> => {
    try {
      return await run(now);
    } catch (error) {
      logger.error("[maintenance] Aşama yarıda kaldı",
        {stage: name, error: String(error)});
      return {...empty, failed: 1};
    }
  };
  const none: PurgeResult = {removed: 0, failed: 0};
  const resumed = await stage("resume", resumeDeletions, none);
  const unverified = await stage("unverified", purgeUnverified, none);
  const closed = await stage("closedLedgers", purgeClosedLedgers, none);
  const tombstones = await stage("tombstones", purgeTombstones, none);
  const web = await stage("web", async (at) => {
    const {requests, guests} = await purgeWebData(at);
    return {removed: requests + guests, failed: 0};
  }, none);
  const notifications =
    await stage("notifications", purgeNotifications, none);
  // Silmelerden sonra: saklama süresi dolup silinen defter denetlenmez.
  const audit = await stage("audit", auditRecentLedgers,
    {audited: 0, problems: 0, skipped: 0, failed: 0});
  return {
    unverified: unverified.removed,
    closedLedgers: closed.removed,
    tombstones: tombstones.removed,
    web: web.removed,
    notifications: notifications.removed,
    resumed: resumed.removed,
    audited: audit.audited,
    auditProblems: audit.problems,
    auditSkipped: audit.skipped,
    failed: unverified.failed + closed.failed + tombstones.failed +
      web.failed + notifications.failed + resumed.failed + audit.failed,
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
