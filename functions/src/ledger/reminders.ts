import {Timestamp, WriteBatch} from "firebase-admin/firestore";
import {onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {z} from "zod";
import {db, REGION} from "../common/firebase";
import {OPTS, Id, fail, parse, readLedger, requireUid} from "./callable";
import {
  Ledger,
  addDays,
  deltaForSide,
  hourIstanbul,
  otherSide,
  todayIstanbul,
} from "./model";
import {Notice, deliver, flushPushQueue} from "./notify";

// Hatırlatmalar nazik ve seyrek olmalı: metni sunucu seçer (gönderen serbest
// metin yazamaz), tutar bildirimde görünmez, aynı kişiye sık gönderilemez,
// gece push atılmaz. Alıcı bir kişiyi sessize alabilir (users.reminderMutes).

export type ReminderKind = "overdue" | "pending" | "balance";
type DueWhen = "soon" | "today" | "late";

/** Aynı kişiye iki hatırlatma arası gün. Vadesi geçmişse daha kısa. */
export const REMINDER_INTERVAL_DAYS = {overdue: 3, pending: 7, balance: 7};
export const DAILY_REMINDER_LIMIT = 10;
const QUIET_FROM = 21;
const QUIET_UNTIL = 9;

/** Testlerde saat değiştirilebilsin diye. */
export const clock = {now: (): Date => new Date()};

/**
 * Elle gönderilen hatırlatmanın metni. İstemcideki önizleme bununla aynıdır.
 * @param {ReminderKind} kind Tür.
 * @param {string} fromName Gönderenin adı.
 * @param {number} waiting Alıcının yanıtını bekleyen kayıt sayısı.
 * @return {object} Başlık ve mesaj.
 */
export function reminderText(
  kind: ReminderKind,
  fromName: string,
  waiting: number
): {title: string; message: string} {
  switch (kind) {
  case "overdue":
    return {
      title: "Vadesi geçmiş kayıt",
      message: `${fromName} ile hesabınızda vadesi geçmiş bir kayıt ` +
        "görünüyor. Uygun olduğunuzda göz atabilirsiniz.",
    };
  case "pending":
    return {
      title: "Yanıtınızı bekleyen kayıt",
      message: `${fromName} ile hesabınızda yanıtınızı bekleyen ${waiting} ` +
        "kayıt var. Uygun olduğunuzda göz atabilirsiniz.",
    };
  case "balance":
    return {
      title: "Hesap hatırlatması",
      message: `${fromName} ile ortak hesabınızda açık bir bakiye ` +
        "görünüyor. Uygun olduğunuzda kontrol edebilirsiniz.",
    };
  }
}

/**
 * Otomatik vade hatırlatmasının metni.
 * @param {DueWhen} when Vadeye göre konum.
 * @param {string} counterpart Karşı tarafın adı.
 * @return {object} Başlık ve mesaj.
 */
export function dueText(
  when: DueWhen,
  counterpart: string
): {title: string; message: string} {
  switch (when) {
  case "soon":
    return {
      title: "Yaklaşan vade",
      message: `${counterpart} ile hesabınızda 3 gün sonra vadesi dolacak ` +
        "bir kayıt var.",
    };
  case "today":
    return {
      title: "Bugün vadesi dolan kayıt",
      message: `${counterpart} ile hesabınızda bugün vadesi dolan bir kayıt ` +
        "var.",
    };
  case "late":
    return reminderText("overdue", counterpart, 0);
  }
}

/**
 * @param {string} day YYYY-MM-DD.
 * @return {string} "2 Ekim".
 */
function formatDay(day: string): string {
  return new Intl.DateTimeFormat("tr-TR", {
    day: "numeric",
    month: "long",
    timeZone: "UTC",
  }).format(new Date(`${day}T00:00:00Z`));
}

/**
 * Sessiz saatlerdeyse push'un gönderileceği sabah, değilse undefined.
 * @param {Date} now An.
 * @return {Date | undefined} Gönderim anı.
 */
export function quietUntil(now: Date): Date | undefined {
  const hour = hourIstanbul(now);
  if (hour >= QUIET_UNTIL && hour < QUIET_FROM) return undefined;
  const today = todayIstanbul(now);
  const day = hour >= QUIET_FROM ? addDays(today, 1) : today;
  // Türkiye yıl boyu UTC+3.
  const hh = String(QUIET_UNTIL).padStart(2, "0");
  return new Date(`${day}T${hh}:00:00+03:00`);
}

const ReminderInput = z.object({ledgerId: Id}).strict();

/**
 * Karşı tarafa nazik bir uygulama içi hatırlatma gönderir. Yalnızca karşı
 * taraf size borçluysa ya da yanıtını bekleyen bir kayıt varsa çalışır.
 */
export const sendReminder = onCall<unknown>(OPTS, async (req) => {
  const uid = requireUid(req);
  const {ledgerId} = parse(ReminderInput, req.data);
  const now = clock.now();
  const today = todayIstanbul(now);
  const ledgerRef = db.collection("ledgers").doc(ledgerId);
  const limitRef = db.collection("rateLimits").doc(`reminders_${uid}`);

  const {notice, result} = await db.runTransaction(async (tx) => {
    const {ledger, side} = await readLedger(tx, ledgerRef, uid);
    const other = otherSide(side);
    const otherUid = ledger.sides[other].uid;
    if (ledger.mode !== "shared" || !otherUid) {
      fail("failed-precondition",
        "Özel defterde hatırlatma gönderilemez; karşı taraf uygulamada değil.");
    }
    const otherName = ledger.sides[other].displayName;
    const open = await tx.get(
      ledgerRef.collection("entries").where("awaitingSide", "==", other)
    );
    const limit = await tx.get(limitRef);

    const waiting = open.docs.filter((d) =>
      d.get("state") === "pending" || d.get("state") === "disputed").length;
    const owes = Object.values(ledger.balances ?? {})
      .some((v) => deltaForSide(side, v) > 0);
    const overdue = (ledger.dueItems ?? [])
      .some((i) => i.debtorSide === other && i.dueOn < today);
    let kind: ReminderKind;
    if (overdue) kind = "overdue";
    else if (waiting > 0) kind = "pending";
    else if (owes) kind = "balance";
    else {
      fail("failed-precondition",
        `Şu an hatırlatılacak bir şey yok: ${otherName} size borçlu ` +
        "görünmüyor ve yanıt bekleyen bir kayıt yok.");
    }

    const interval = REMINDER_INTERVAL_DAYS[kind];
    const lastOn = ledger.reminders?.[side]?.lastOn;
    if (lastOn && today < addDays(lastOn, interval)) {
      fail("resource-exhausted",
        "Bu kişiye yakın zamanda hatırlatma gönderdiniz. Bir sonraki " +
        `hatırlatma: ${formatDay(addDays(lastOn, interval))}.`);
    }
    const count = limit.get("day") === today ?
      (limit.get("count") as number) : 0;
    if (count >= DAILY_REMINDER_LIMIT) {
      fail("resource-exhausted",
        "Bugünkü hatırlatma sınırına ulaştınız. Yarın tekrar " +
        "gönderebilirsiniz.");
    }

    tx.set(limitRef, {day: today, count: count + 1});
    tx.update(ledgerRef, {
      [`reminders.${side}`]: {
        lastAt: Timestamp.fromDate(now),
        lastOn: today,
        kind,
      },
    });
    const pushAfter = quietUntil(now);
    const notice: Notice = {
      uid: otherUid,
      setting: "reminders",
      type: "reminder",
      ...reminderText(kind, ledger.sides[side].displayName, waiting),
      ledgerId,
      entryId: null,
      pushAfter,
    };
    const queued = pushAfter !== undefined;
    return {
      notice,
      result: {kind, queued, nextOn: addDays(today, interval)},
    };
  });

  await deliver([notice]);
  return result;
});

const URGENCY: {[w in DueWhen]: number} = {soon: 1, today: 2, late: 3};

/**
 * Vade hatırlatmaları: borçluya vadeden 3 gün önce, vade günü, 3 ve 7 gün
 * sonra; alacaklıya yalnızca vade günü. Bir kişiye defter başına günde en
 * fazla bir bildirim gider. Aynı gün ikinci çalıştırma tekrar göndermez.
 * @param {Date} now An.
 * @return {Promise<object>} Özet.
 */
export async function runDailyReminders(
  now: Date
): Promise<{notified: number; flushed: number}> {
  const today = todayIstanbul(now);
  const flushed = await flushPushQueue(now);
  const whenOf = new Map<string, DueWhen>([
    [addDays(today, 3), "soon"],
    [today, "today"],
    [addDays(today, -3), "late"],
    [addDays(today, -7), "late"],
  ]);
  const snap = await db.collection("ledgers")
    .where("dueDates", "array-contains-any", [...whenOf.keys()])
    .get();

  const notices: Notice[] = [];
  const batches: WriteBatch[] = [];
  let ops = 0;
  for (const doc of snap.docs) {
    const ledger = doc.data() as Ledger;
    if (ledger.status !== "active" || ledger.dueRemindedOn === today) continue;
    const picked = new Map<string, {when: DueWhen; name: string}>();
    const pick = (uid: string | null, when: DueWhen, name: string) => {
      if (!uid) return;
      const current = picked.get(uid);
      if (!current || URGENCY[when] > URGENCY[current.when]) {
        picked.set(uid, {when, name});
      }
    };
    for (const item of ledger.dueItems ?? []) {
      const when = whenOf.get(item.dueOn);
      if (!when) continue;
      const debtor = ledger.sides[item.debtorSide];
      const creditor = ledger.sides[otherSide(item.debtorSide)];
      pick(debtor.uid, when, creditor.displayName);
      if (when === "today") pick(creditor.uid, "today", debtor.displayName);
    }
    if (picked.size === 0) continue;
    if (ops % 400 === 0) batches.push(db.batch());
    batches[batches.length - 1].update(doc.ref, {dueRemindedOn: today});
    ops++;
    for (const [uid, p] of picked) {
      notices.push({
        uid,
        setting: "reminders",
        type: "dueReminder",
        ...dueText(p.when, p.name),
        ledgerId: doc.id,
        entryId: null,
      });
    }
  }
  // Önce işaretle, sonra gönder: yeniden denemede aynı gün ikinci kez gitmez.
  for (const b of batches) await b.commit();
  await deliver(notices);
  return {notified: notices.length, flushed};
}

export const dailyReminders = onSchedule(
  {schedule: "every day 09:00", timeZone: "Europe/Istanbul", region: REGION},
  async () => {
    const summary = await runDailyReminders(clock.now());
    logger.info("[reminders] Günlük hatırlatmalar", summary);
  }
);
