import {createHash, randomBytes} from "node:crypto";
import {
  DocumentReference,
  FieldValue,
  Timestamp,
  Transaction,
} from "firebase-admin/firestore";
import {CallableRequest, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {z} from "zod";
import {admin, db} from "../common/firebase";
import {MAX_MINOR, formatMinor} from "./assets";
import {OPTS, Id, consumeDaily, fail, parse, requireUid} from "./callable";
import {DISPUTE_REASONS, displayNameOf} from "./commands";
import {authInfo} from "./contacts";
import {Entry, EntryKind, Ledger, deltaForSide, todayIstanbul} from "./model";
import {Notice, deliver} from "./notify";

// Uygulaması olmayan karşı tarafın onayı (Faz 2c, e-posta sürümü).
//
// Özel defterin sahibi bir kayıt için onay linki oluşturur ve kendi
// WhatsApp'ından gönderir (Pacta kimseye mesaj atmaz). Link /o/<token>
// sayfasını açar. Karşı taraf e-posta adresini Firebase'in e-posta
// bağlantısıyla doğrular, kaydı görür ve onaylar, itiraz eder ya da
// reddeder. Özel defterin bakiyesi değişmez (defter sahibinin notudur);
// yanıt kayda kanıt olarak eklenir ve sahibe bildirilir.
//
// - Token yalnızca linkte durur; sunucuda özeti (webRequests/{sha256})
//   saklanır. webRequests ve webGuests istemciye kapalıdır.
// - İstek, onu ilk açan doğrulanmış e-postaya bağlanır: link başkasına
//   iletilse de o kişi yanıtlayamaz.
// - E-posta bağlantısıyla giriş bir Auth hesabı açar. Pacta hesabı olmayan
//   bu misafir hesapları (webGuests) yanıttan hemen sonra, yanıtlanmazsa
//   bir gün içinde silinir: kişi sonra uygulamaya aynı adresle kaydolabilir.

export const WEB_CONFIRM_BASE = "https://pacta-76686.web.app/o/";

/** Link bu kadar gün geçerlidir. */
export const REQUEST_DAYS = 14;

/** Yanıtlanmayan istek, süresi dolduktan bu kadar gün sonra silinir. */
export const PURGE_AFTER_DAYS = 30;

/** Kişi başına günlük link sınırı. */
export const DAILY_WEB_REQUESTS = 30;

/** Yanıt vermeden kalan misafir girişleri bu kadar saat sonra silinir. */
export const GUEST_HOURS = 24;

const DAY_MS = 24 * 60 * 60 * 1000;

/** Testlerde saat değiştirilebilsin diye. */
export const webClock = {now: (): Date => new Date()};

const Token = z.string().regex(/^[A-Za-z0-9_-]{32}$/);
const Text = z.string().trim().max(280);
const Amount = z.number().int().positive().max(MAX_MINOR);

export const REJECT_REASONS = {
  notAgreed: "Böyle bir anlaşmamız yok",
  unknownPerson: "Bu kişiyi tanımıyorum",
  other: "Diğer",
} as const;

const RequestInput = z.object({
  ledgerId: Id,
  entryId: Id,
  includeDescription: z.boolean().default(true),
  /** Verilirse link yalnızca bu adresle açılır (sahip kendi başka adresiyle
   * onaylayamaz). */
  recipientEmail: z.string().trim().toLowerCase().email("Geçerli bir " +
    "e-posta adresi girin.").max(254).optional(),
}).strict();

const OpenInput = z.object({token: Token}).strict();

const RespondInput = z.discriminatedUnion("action", [
  z.object({token: Token, action: z.literal("confirm")}).strict(),
  z.object({
    token: Token,
    action: z.literal("dispute"),
    reason: z.enum(["amount", "date", "description", "duplicate", "other"]),
    note: Text.default(""),
    suggestedAmountMinor: Amount.nullable().default(null),
  }).strict(),
  z.object({
    token: Token,
    action: z.literal("reject"),
    reason: z.enum(["notAgreed", "unknownPerson", "other"]),
    note: Text.default(""),
  }).strict(),
]);

type WebAction = "confirm" | "dispute" | "reject";

/** Kayıtta görünen yanıt durumu. */
const ANSWER_STATE = {
  confirm: "confirmed",
  dispute: "disputed",
  reject: "rejected",
} as const;

const EVENT_TYPE = {
  confirm: "webConfirmed",
  dispute: "webDisputed",
  reject: "webRejected",
} as const;

interface WebResponse {
  action: WebAction;
  reason: string | null;
  note: string;
  suggestedAmountMinor: number | null;
  email: string;
  uid: string;
  userAgent: string;
  /** Sunucunun gördüğü adres (Google ön ucu). */
  ip: string;
  /** x-forwarded-for zincirinin tamamı; ilk değeri istemci uydurabilir. */
  forwardedFor: string;
}

interface WebRequest {
  ownerUid: string;
  ownerName: string;
  counterpartyName: string;
  ledgerId: string;
  entryId: string;
  version: number;
  contentHash: string;
  kind: EntryKind;
  deltaMinor: number;
  asset: string;
  amountMinor: number;
  occurredOn: string;
  dueOn: string | null;
  description: string;
  state: "open" | "answered" | "revoked";
  expiresAt: Timestamp;
  boundEmail: string | null;
  /** Sahip alıcının e-postasını baştan belirtti (boundEmail o adres). */
  recipientSet?: boolean;
  response: WebResponse | null;
}

/** Web sayfasının gösterdiği durum. */
type Status = "open" | "answered" | "expired" | "revoked" | "withdrawn";

/**
 * @param {string} token Linkteki anahtar.
 * @return {DocumentReference} İstek belgesi (kimliği anahtarın özeti).
 */
function requestRef(token: string): DocumentReference {
  const key = createHash("sha256").update(token, "utf8").digest("hex");
  return db.collection("webRequests").doc(key);
}

/**
 * Sahibin göreceği gizlenmiş e-posta: "a***@gmail.com".
 * @param {string} email E-posta.
 * @return {string} Gizlenmiş hâli.
 */
export function maskEmail(email: string): string {
  const at = email.lastIndexOf("@");
  if (at <= 0) return "***";
  return `${email.slice(0, 1)}***${email.slice(at)}`;
}

/**
 * Kaydı karşı tarafın (b) bakış açısından anlatır.
 * @param {WebRequest} r İstek.
 * @return {string} Cümle.
 */
export function webSentence(
  r: Pick<WebRequest, "kind" | "deltaMinor" | "asset" | "amountMinor"> &
    {ownerName: string}
): string {
  const amount = formatMinor(r.amountMinor, r.asset);
  const mine = deltaForSide("b", r.deltaMinor);
  if (r.kind === "payment") {
    return mine < 0 ?
      `${r.ownerName}, size ${amount} ödeme yaptığını kaydetti.` :
      `${r.ownerName}, sizden ${amount} ödeme aldığını kaydetti.`;
  }
  return mine < 0 ?
    `${r.ownerName}, size ${amount} borç verdiğini kaydetti.` :
    `${r.ownerName}, sizden ${amount} borç aldığını kaydetti.`;
}

/**
 * E-postası doğrulanmış web oturumu (e-posta bağlantısıyla giriş).
 * @param {CallableRequest<unknown>} req İstek.
 * @return {object | null} Kullanıcı ya da oturum yoksa null.
 */
function webUser(
  req: CallableRequest<unknown>
): {uid: string; email: string} | null {
  const token = req.auth?.token;
  if (!req.auth || !token?.email || token.email_verified !== true) return null;
  return {uid: req.auth.uid, email: String(token.email).toLowerCase()};
}

/**
 * İsteğin güncel durumu. Kayıt değiştiyse (düzeltildi, defter taşındı ya
 * da silindi) link artık yanıt kabul etmez.
 * @param {Transaction} tx Transaction.
 * @param {WebRequest} r İstek.
 * @param {Date} now An.
 * @return {Promise<Status>} Durum.
 */
async function liveStatus(
  tx: Transaction,
  r: WebRequest,
  now: Date
): Promise<Status> {
  if (r.state === "revoked") return "revoked";
  if (r.state === "answered") return "answered";
  if (r.expiresAt.toMillis() <= now.getTime()) return "expired";
  const ledgerRef = db.collection("ledgers").doc(r.ledgerId);
  const [ledgerSnap, entrySnap] = [
    await tx.get(ledgerRef),
    await tx.get(ledgerRef.collection("entries").doc(r.entryId)),
  ];
  const ledger = ledgerSnap.data() as Ledger | undefined;
  const entry = entrySnap.data() as Entry | undefined;
  if (
    !ledger || ledger.mode !== "private" || ledger.status !== "active" ||
    ledger.sides.a.uid !== r.ownerUid ||
    !entry || entry.state !== "confirmed" || entry.reversedBy ||
    entry.contentHash !== r.contentHash
  ) {
    return "withdrawn";
  }
  return "open";
}

/**
 * Doğrulanmış kişiye gösterilen ayrıntılar.
 * @param {WebRequest} r İstek.
 * @param {string} email Doğrulanan e-posta.
 * @return {object} Ayrıntılar.
 */
function details(r: WebRequest, email: string) {
  return {
    sentence: webSentence(r),
    amount: formatMinor(r.amountMinor, r.asset),
    asset: r.asset,
    occurredOn: r.occurredOn,
    dueOn: r.dueOn,
    description: r.description,
    email,
  };
}

/**
 * Pacta hesabı olmayan web oturumunu misafir olarak işaretler; bakım ya da
 * yanıt sonrası silinir.
 * @param {string} uid Oturum.
 */
async function markGuest(uid: string): Promise<void> {
  if ((await db.collection("users").doc(uid).get()).exists) return;
  try {
    await db.collection("webGuests").doc(uid)
      .create({createdAt: FieldValue.serverTimestamp()});
  } catch (error) {
    // Zaten işaretli.
    if ((error as {code?: number}).code !== 6) throw error;
  }
}

/**
 * Misafir giriş hesabını siler. Kişi bu arada Pacta hesabı açtıysa (profili
 * varsa) ya da bir defterin tarafıysa hesaba dokunulmaz, yalnızca işaret
 * kalkar: yanlışlıkla gerçek bir hesap silinmez.
 * @param {string} uid Oturum.
 * @return {Promise<boolean>} Misafir miydi.
 */
export async function removeGuest(uid: string): Promise<boolean> {
  const guestRef = db.collection("webGuests").doc(uid);
  if (!(await guestRef.get()).exists) return false;
  const [profile, ledgers] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.collection("ledgers").where("memberUids", "array-contains", uid)
      .limit(1).get(),
  ]);
  if (!ledgers.empty) {
    logger.warn("[web] Misafir işaretli hesap bir defterin tarafı; " +
      "silinmedi", {uid});
  }
  if (!profile.exists && ledgers.empty) {
    try {
      await admin.auth().deleteUser(uid);
    } catch (error) {
      if ((error as {code?: string}).code !== "auth/user-not-found") {
        throw error;
      }
    }
  }
  await guestRef.delete();
  return true;
}

/**
 * Özel defterdeki bir kayıt için karşı tarafa gönderilecek onay linki.
 * Aynı kayıt için önceki link geçersiz olur. Açıklama istenmezse gitmez
 * (özel not olabilir).
 */
export const requestWebConfirmation = onCall<unknown>(OPTS, async (req) => {
  const uid = await requireUid(req);
  const input = parse(RequestInput, req.data);
  await consumeDaily(`webrequests_${uid}`, DAILY_WEB_REQUESTS,
    "Bugün çok fazla onay linki oluşturdunuz. Yarın tekrar deneyin.");
  const me = await db.collection("users").doc(uid).get();
  const ownerName = displayNameOf(me,
    (await authInfo(uid))?.displayName ?? null);
  const token = randomBytes(24).toString("base64url");
  const ref = requestRef(token);
  const now = webClock.now();
  const expiresAt = Timestamp.fromMillis(now.getTime() + REQUEST_DAYS * DAY_MS);
  const ledgerRef = db.collection("ledgers").doc(input.ledgerId);
  const entryRef = ledgerRef.collection("entries").doc(input.entryId);

  await db.runTransaction(async (tx) => {
    const ledgerSnap = await tx.get(ledgerRef);
    const ledger = ledgerSnap.data() as Ledger | undefined;
    if (!ledger || ledger.sides.a.uid !== uid) {
      fail("not-found", "Defter bulunamadı.");
    }
    if (ledger.mode !== "private") {
      fail("failed-precondition",
        "Ortak defterde karşı taraf kaydı uygulamada onaylar.");
    }
    if (ledger.status !== "active") {
      fail("failed-precondition", "Defter kapalı.");
    }
    const entrySnap = await tx.get(entryRef);
    const entry = entrySnap.data() as Entry | undefined;
    if (!entry) fail("not-found", "Kayıt bulunamadı.");
    if (
      entry.state !== "confirmed" || entry.kind === "reversal" ||
      entry.reversedBy
    ) {
      fail("failed-precondition", "Bu kayıt için onay istenemez.");
    }
    const current = entrySnap.get("webConfirmation") as
      {state?: string; requestKey?: string} | undefined;
    if (current?.state === "confirmed") {
      fail("failed-precondition", "Bu kaydı karşı taraf zaten onayladı.");
    }
    const oldRef = current?.requestKey ?
      db.collection("webRequests").doc(current.requestKey) :
      null;
    const old = oldRef ? await tx.get(oldRef) : null;

    if (oldRef && old?.get("state") === "open") {
      tx.update(oldRef, {state: "revoked"});
    }
    tx.set(ref, {
      ownerUid: uid,
      ownerName,
      counterpartyName: ledger.sides.b.displayName,
      ledgerId: input.ledgerId,
      entryId: input.entryId,
      version: entry.version,
      contentHash: entry.contentHash,
      kind: entry.kind,
      deltaMinor: entry.deltaMinor,
      asset: entry.asset,
      amountMinor: entry.amountMinor,
      occurredOn: entry.occurredOn,
      dueOn: entry.dueOn,
      description: input.includeDescription ? entry.description : "",
      state: "open",
      expiresAt,
      // Yanıtlanınca kalkar; yanıtlanan istek kayıtla birlikte saklanır.
      purgeAfter: Timestamp.fromMillis(
        expiresAt.toMillis() + PURGE_AFTER_DAYS * DAY_MS),
      // Alıcı belirtildiyse istek baştan o adrese bağlıdır.
      boundEmail: input.recipientEmail ?? null,
      recipientSet: input.recipientEmail !== undefined,
      response: null,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(entryRef, {
      webConfirmation: {
        state: "requested",
        requestKey: ref.id,
        requestedAt: FieldValue.serverTimestamp(),
        expiresAt,
        recipientSet: input.recipientEmail !== undefined,
        recipientMasked: input.recipientEmail ?
          maskEmail(input.recipientEmail) :
          null,
      },
    });
    tx.set(ledgerRef.collection("events").doc(), {
      type: "webRequested",
      entryId: input.entryId,
      version: entry.version,
      contentHash: entry.contentHash,
      actorUid: uid,
      memberUids: entry.memberUids,
      at: FieldValue.serverTimestamp(),
    });
  });

  return {
    url: WEB_CONFIRM_BASE + token,
    expiresOn: todayIstanbul(expiresAt.toDate()),
  };
});

/**
 * Web sayfası linki açınca çağırır; oturum gerekmez. Oturum yoksa yalnızca
 * durum ve gönderenin adı döner. E-postası doğrulanmış oturumla kaydın
 * ayrıntısı gelir ve istek o e-postaya bağlanır.
 */
export const openWebConfirmation = onCall<unknown>(OPTS, async (req) => {
  const {token} = parse(OpenInput, req.data);
  const user = webUser(req);
  const ref = requestRef(token);
  const now = webClock.now();

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return {status: "invalid"};
    const r = snap.data() as WebRequest;
    const status = await liveStatus(tx, r, now);
    // Alıcı belirtildiyse sayfa doğrulanacak adresi gizlenmiş olarak söyler.
    const base = {
      status,
      ownerName: r.ownerName,
      ...(r.recipientSet && r.boundEmail ?
        {recipientMasked: maskEmail(r.boundEmail)} :
        {}),
    };
    if (status === "answered") {
      // Yanıtı yalnızca yanıtlayan görür.
      return user && user.email === r.boundEmail ?
        {...base, answer: r.response?.action, ...details(r, user.email)} :
        base;
    }
    if (status !== "open" || !user) return base;
    if (user.uid === r.ownerUid) {
      fail("failed-precondition",
        "Bu onay linkini siz oluşturdunuz. Linki karşı tarafa gönderin.");
    }
    if (r.boundEmail && r.boundEmail !== user.email) {
      return {...base, status: "otherEmail"};
    }
    if (!r.boundEmail) {
      tx.update(ref, {
        boundEmail: user.email,
        boundAt: FieldValue.serverTimestamp(),
      });
    }
    return {...base, ...details(r, user.email)};
  });

  // Durum ne olursa olsun: e-posta bağlantısıyla açılan her profilsiz
  // oturum misafirdir ve temizlenir.
  if (user) await markGuest(user.uid);
  return result;
});

/**
 * @param {Status} status Açık olmayan istek durumu.
 * @return {string} Kullanıcıya mesaj.
 */
function closedMessage(status: Status): string {
  switch (status) {
  case "expired":
    return "Bu linkin süresi doldu. Gönderen kişiden yeni link isteyin.";
  case "revoked":
    return "Bu link yenilendi. Gönderen kişinin son gönderdiği linki açın.";
  case "answered":
    return "Bu istek zaten yanıtlandı.";
  default:
    return "Kayıt değişti ya da kaldırıldı; bu link artık geçerli değil.";
  }
}

/**
 * Doğrulanmış e-postayla yanıt: onay, itiraz ya da ret. Kayıt ve olay
 * yazılır, sahibe bildirim gider; misafir giriş hesabı silinir. Aynı
 * yanıtın tekrarı aynı sonucu döner.
 */
export const respondWebConfirmation = onCall<unknown>(OPTS, async (req) => {
  const input = parse(RespondInput, req.data);
  const user = webUser(req);
  if (!user) {
    fail("unauthenticated", "Önce e-posta adresinizi doğrulayın.");
  }
  const ref = requestRef(input.token);
  const now = webClock.now();
  const notices: Notice[] = [];
  const headers = req.rawRequest?.headers ?? {};
  const userAgent = String(headers["user-agent"] ?? "").slice(0, 300);
  const forwardedFor = String(headers["x-forwarded-for"] ?? "").slice(0, 300);
  const ip = String(req.rawRequest?.ip ?? "").slice(0, 64);

  const result = await db.runTransaction(async (tx) => {
    // Çakışmada transaction yeniden çalışır; bildirimler çoğalmasın.
    notices.length = 0;
    const snap = await tx.get(ref);
    if (!snap.exists) fail("not-found", "Onay isteği bulunamadı.");
    const r = snap.data() as WebRequest;
    const status = await liveStatus(tx, r, now);
    if (status === "answered") {
      if (r.boundEmail === user.email && r.response?.action === input.action) {
        return {status, answer: input.action};
      }
      fail("failed-precondition", closedMessage(status));
    }
    if (status !== "open") fail("failed-precondition", closedMessage(status));
    if (user.uid === r.ownerUid) {
      fail("failed-precondition",
        "Bu onay linkini siz oluşturdunuz. Linki karşı tarafa gönderin.");
    }
    if (r.boundEmail && r.boundEmail !== user.email) {
      fail("permission-denied",
        "Bu link başka bir e-posta adresine bağlı.");
    }

    const reason = input.action === "confirm" ? null : input.reason;
    const note = input.action === "confirm" ? "" : input.note;
    const suggested = input.action === "dispute" ?
      input.suggestedAmountMinor :
      null;
    const masked = maskEmail(user.email);
    tx.update(ref, {
      state: "answered",
      boundEmail: user.email,
      purgeAfter: FieldValue.delete(),
      response: {
        action: input.action,
        reason,
        note,
        suggestedAmountMinor: suggested,
        email: user.email,
        uid: user.uid,
        userAgent,
        ip,
        forwardedFor,
        at: FieldValue.serverTimestamp(),
      },
    });
    const ledgerRef = db.collection("ledgers").doc(r.ledgerId);
    tx.update(ledgerRef.collection("entries").doc(r.entryId), {
      "webConfirmation.state": ANSWER_STATE[input.action],
      "webConfirmation.respondedAt": FieldValue.serverTimestamp(),
      "webConfirmation.emailMasked": masked,
      "webConfirmation.reason": reason,
      "webConfirmation.note": note,
      "webConfirmation.suggestedAmountMinor": suggested,
      "updatedAt": FieldValue.serverTimestamp(),
    });
    tx.set(ledgerRef.collection("events").doc(), {
      type: EVENT_TYPE[input.action],
      entryId: r.entryId,
      version: r.version,
      contentHash: r.contentHash,
      actorUid: "",
      via: "web",
      emailMasked: masked,
      reason,
      memberUids: [r.ownerUid],
      at: FieldValue.serverTimestamp(),
    });

    const name = r.counterpartyName;
    const amount = formatMinor(r.amountMinor, r.asset);
    const why = input.action === "dispute" ?
      DISPUTE_REASONS[input.reason] :
      input.action === "reject" ? REJECT_REASONS[input.reason] : "";
    const quoted = note ? ` — “${note}”` : ".";
    notices.push({
      uid: r.ownerUid,
      setting: "statusChanges",
      type: EVENT_TYPE[input.action],
      title: input.action === "confirm" ? "Kayıt onaylandı" :
        input.action === "dispute" ? "Kayda itiraz edildi" :
          "Kayıt reddedildi",
      message: input.action === "confirm" ?
        `${name} kaydı web'de onayladı: ${amount}.` :
        input.action === "dispute" ?
          `${name} kayda itiraz etti: ${why}${quoted}` :
          `${name} kaydı reddetti: ${why}${quoted}`,
      ledgerId: r.ledgerId,
      entryId: r.entryId,
    });
    return {status: "answered", answer: input.action};
  });

  await deliver(notices);
  try {
    await removeGuest(user.uid);
  } catch (error) {
    // Bakım bir gün içinde tekrar dener.
    logger.error("[web] Misafir hesabı silinemedi", {error: String(error)});
  }
  return result;
});

/**
 * Bakım: yanıtlanmayan eski istekleri ve bir günden eski misafir
 * girişlerini siler.
 * @param {Date} now An.
 * @return {Promise<object>} Silinen sayıları.
 */
export async function purgeWebData(
  now: Date
): Promise<{requests: number; guests: number}> {
  let requests = 0;
  for (;;) {
    const snap = await db.collection("webRequests")
      .where("purgeAfter", "<", Timestamp.fromDate(now))
      .limit(400)
      .get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    requests += snap.size;
    if (snap.size < 400) break;
  }
  let guests = 0;
  const stale = await db.collection("webGuests")
    .where("createdAt", "<",
      Timestamp.fromMillis(now.getTime() - GUEST_HOURS * 60 * 60 * 1000))
    .get();
  for (const doc of stale.docs) {
    // Biri düşerse diğerleri yine temizlenir; ertesi gün tekrar denenir.
    try {
      await removeGuest(doc.id);
      guests++;
    } catch (error) {
      logger.error("[web] Misafir silinemedi",
        {uid: doc.id, error: String(error)});
    }
  }
  return {requests, guests};
}
