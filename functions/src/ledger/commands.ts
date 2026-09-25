import {
  DocumentReference,
  DocumentSnapshot,
  FieldValue,
  Transaction,
} from "firebase-admin/firestore";
import {onCall} from "firebase-functions/v2/https";
import {z} from "zod";
import {db} from "../common/firebase";
import {ASSET_CODES, MAX_MINOR, formatMinor} from "./assets";
import {OPTS, Id, fail, parse, readLedger, requireUid} from "./callable";
import {
  Entry,
  EntryContent,
  Ledger,
  LedgerSide,
  Side,
  chainHash,
  contentHash,
  deltaFor,
  deltaForSide,
  directionFor,
  isAgainstProposer,
  isValidDate,
  otherSide,
  todayIstanbul,
} from "./model";
import {Notice, deliver} from "./notify";

// Durum geçişleri yalnızca bu komutlarla yapılır; istemci ledgers altına
// yazamaz (firestore.rules). Her komut tek transaction'dır.

const DateStr = z.string().refine(isValidDate, "Geçersiz tarih.");
const Amount = z.number().int().positive().max(MAX_MINOR);
const Text = z.string().trim().max(280);
const EntryKey = {ledgerId: Id, entryId: Id, expectedVersion: z.number().int()};

const CreateLedgerInput = z.union([
  z.object({counterpartyUid: z.string().min(1).max(128)}).strict(),
  z.object({privateName: z.string().trim().min(1).max(80)}).strict(),
]);

const CreateEntryInput = z.object({
  ledgerId: Id,
  entryId: Id,
  kind: z.enum(["debt", "payment"]),
  iGave: z.boolean(),
  asset: z.enum(ASSET_CODES),
  amountMinor: Amount,
  occurredOn: DateStr,
  dueOn: DateStr.nullable().default(null),
  description: Text.default(""),
  linkedEntryId: Id.nullable().default(null),
}).strict();

const ConfirmInput = z.object(EntryKey).strict();
const CancelInput = z.object(EntryKey).strict();

const DISPUTE_REASONS = {
  amount: "Tutar yanlış",
  date: "Tarih yanlış",
  description: "Açıklama yanlış",
  duplicate: "Mükerrer kayıt",
  other: "Diğer",
} as const;

const DisputeInput = z.object({
  ...EntryKey,
  reason: z.enum(["amount", "date", "description", "duplicate", "other"]),
  note: Text.default(""),
  suggestedAmountMinor: Amount.nullable().default(null),
}).strict();

const RejectInput = z.object({
  ...EntryKey,
  reason: z.enum(["unknownPerson", "notAgreed", "other"]),
  note: Text.default(""),
}).strict();

const ReviseInput = z.object({
  ...EntryKey,
  amountMinor: Amount.optional(),
  asset: z.enum(ASSET_CODES).optional(),
  occurredOn: DateStr.optional(),
  dueOn: DateStr.nullable().optional(),
  description: Text.optional(),
}).strict();

const ReverseInput = z.object({
  ledgerId: Id,
  entryId: Id,
  reversalId: Id,
  note: Text.default(""),
}).strict();

type StoredEntry = Entry & {
  confirmation: {uid: string; version: number} | null;
};

/**
 * @param {string} ledgerId Defter.
 * @param {string} entryId Kayıt.
 * @return {object} Referanslar.
 */
function refsFor(ledgerId: string, entryId: string) {
  const ledgerRef = db.collection("ledgers").doc(ledgerId);
  return {ledgerRef, entryRef: ledgerRef.collection("entries").doc(entryId)};
}

/**
 * @param {string} uid Alıcı.
 * @param {string} entryId Kayıt.
 * @return {DocumentReference} Gelen kutusu öğesi.
 */
function inboxRef(uid: string, entryId: string): DocumentReference {
  return db.collection("users").doc(uid).collection("inbox").doc(entryId);
}

/**
 * @param {Transaction} tx Transaction.
 * @param {DocumentReference} ref Kayıt.
 * @return {Promise<StoredEntry>} Kayıt.
 */
async function readEntry(
  tx: Transaction,
  ref: DocumentReference
): Promise<StoredEntry> {
  const snap = await tx.get(ref);
  if (!snap.exists) fail("not-found", "Kayıt bulunamadı.");
  return snap.data() as StoredEntry;
}

/**
 * Kullanıcı eski bir sürüme bakarak işlem yapıyorsa reddeder.
 * @param {Entry} entry Kayıt.
 * @param {number} expected İstemcinin gördüğü sürüm.
 */
function assertVersion(entry: Entry, expected: number) {
  if (entry.version !== expected) {
    fail("failed-precondition", "STALE_VERSION: Kayıt değişti, yenileyin.");
  }
}

/**
 * @param {DocumentSnapshot} user Kullanıcı belgesi.
 * @return {string} Görünen ad.
 */
function displayNameOf(user: DocumentSnapshot): string {
  const name = (user.get("adSoyad") as string | undefined)?.trim();
  return name || "Pacta kullanıcısı";
}

/**
 * Bir kaydı alıcının bakış açısından tek cümleyle anlatır.
 * @param {Side} recipient Alıcının tarafı.
 * @param {Entry} e Kayıt.
 * @param {string} from Kaydı girenin adı.
 * @param {boolean} pending Onay bekliyor mu.
 * @return {string} Cümle.
 */
function describe(
  recipient: Side,
  e: Pick<Entry, "kind" | "deltaMinor" | "asset" | "amountMinor">,
  from: string,
  pending: boolean
): string {
  const amount = formatMinor(e.amountMinor, e.asset);
  const mine = deltaForSide(recipient, e.deltaMinor);
  if (e.kind === "reversal") {
    return pending ?
      `${from} bir kaydı düzeltmek istiyor: ${amount}.` :
      `${from} bir kaydı düzeltti: ${amount}.`;
  }
  if (e.kind === "payment") {
    return mine < 0 ?
      `${from} size ${amount} ödeme yaptığını bildirdi.` :
      `${from}, sizden ${amount} ödeme aldığını kaydetti.`;
  }
  return mine < 0 ?
    `${from} size ${amount} borç yazdı.` :
    `${from}, sizden ${amount} borç aldığını kaydetti.`;
}

/**
 * @param {string} type Öğe türü.
 * @param {Entry} e Kayıt.
 * @param {string} entryId Kayıt kimliği.
 * @param {Side} recipient Alıcının tarafı.
 * @param {string} fromName Gönderenin adı.
 * @return {object} Gelen kutusu öğesi.
 */
function inboxItem(
  type: "confirmEntry" | "reviseEntry",
  e: Entry,
  entryId: string,
  recipient: Side,
  fromName: string
) {
  return {
    type,
    ledgerId: e.ledgerId,
    entryId,
    fromName,
    kind: e.kind,
    asset: e.asset,
    amountMinor: e.amountMinor,
    myDeltaMinor: deltaForSide(recipient, e.deltaMinor),
    description: e.description,
    version: e.version,
    createdAt: FieldValue.serverTimestamp(),
  };
}

/**
 * @param {Transaction} tx Transaction.
 * @param {DocumentReference} ledgerRef Defter.
 * @param {Entry} e Kayıt.
 * @param {string} entryId Kayıt kimliği.
 * @param {string} type Olay.
 * @param {string} actorUid Yapan.
 */
function addEvent(
  tx: Transaction,
  ledgerRef: DocumentReference,
  e: Entry,
  entryId: string,
  type: string,
  actorUid: string
) {
  tx.set(ledgerRef.collection("events").doc(), {
    type,
    entryId,
    version: e.version,
    contentHash: e.contentHash,
    actorUid,
    memberUids: e.memberUids,
    at: FieldValue.serverTimestamp(),
  });
}

/**
 * Sürümün değişmez kopyası.
 * @param {Transaction} tx Transaction.
 * @param {DocumentReference} entryRef Kayıt.
 * @param {Entry} e Kayıt.
 * @param {string} byUid Sürümü oluşturan.
 */
function addRevision(
  tx: Transaction,
  entryRef: DocumentReference,
  e: Entry,
  byUid: string
) {
  tx.set(entryRef.collection("revisions").doc(String(e.version)), {
    kind: e.kind,
    direction: e.direction,
    asset: e.asset,
    amountMinor: e.amountMinor,
    occurredOn: e.occurredOn,
    dueOn: e.dueOn,
    description: e.description,
    linkedEntryId: e.linkedEntryId,
    version: e.version,
    contentHash: e.contentHash,
    byUid,
    memberUids: e.memberUids,
    at: FieldValue.serverTimestamp(),
  });
}

/**
 * Onayı deftere işler: bakiye, sıra ve zincir.
 * @param {Transaction} tx Transaction.
 * @param {DocumentReference} ledgerRef Defter.
 * @param {Ledger} ledger Okunmuş defter.
 * @param {Entry} e Kayıt.
 * @param {number} pendingChange Bekleyen sayısındaki değişim.
 * @return {object} Kayda yazılacak sıra ve zincir.
 */
function commitToLedger(
  tx: Transaction,
  ledgerRef: DocumentReference,
  ledger: Ledger,
  e: Entry,
  pendingChange: number
) {
  const seq = ledger.head.seq + 1;
  const chain = chainHash(ledger.head.chainHash, e.contentHash, seq);
  const update: {[field: string]: unknown} = {
    [`balances.${e.asset}`]: FieldValue.increment(e.deltaMinor),
    "head.seq": seq,
    "head.chainHash": chain,
    "updatedAt": FieldValue.serverTimestamp(),
    "lastEntryAt": FieldValue.serverTimestamp(),
  };
  if (pendingChange !== 0) {
    update.pendingCount = FieldValue.increment(pendingChange);
  }
  tx.update(ledgerRef, update);
  return {confirmedSeq: seq, chainHash: chain};
}

/**
 * @param {string} mode Defter türü.
 * @param {LedgerSide} a Oluşturan.
 * @param {LedgerSide} b Karşı taraf.
 * @param {string[]} memberUids Üyeler.
 * @return {object} Yeni defter.
 */
function newLedger(
  mode: "shared" | "private",
  a: LedgerSide,
  b: LedgerSide,
  memberUids: string[]
) {
  return {
    mode,
    status: "active",
    sides: {a, b},
    memberUids,
    balances: {},
    pendingCount: 0,
    head: {seq: 0, chainHash: ""},
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    lastEntryAt: FieldValue.serverTimestamp(),
  };
}

/**
 * Yeni kaydı yazar; aleyhe ya da özel defterdeyse hemen onaylar.
 * createEntry ve reverseEntry ortak yolu.
 * @param {Transaction} tx Transaction.
 * @param {object} ctx Bağlam.
 * @return {object} Sonuç.
 */
function writeNewEntry(
  tx: Transaction,
  ctx: {
    uid: string;
    side: Side;
    ledger: Ledger;
    ledgerId: string;
    entryId: string;
    content: EntryContent;
    notices: Notice[];
  }
) {
  const {uid, side, ledger, ledgerId, entryId, content, notices} = ctx;
  const {ledgerRef, entryRef} = refsFor(ledgerId, entryId);
  const delta = deltaFor(content.direction, content.amountMinor);
  const hash = contentHash(ledgerId, entryId, content, 1);
  const shared = ledger.mode === "shared";
  const auto = !shared || isAgainstProposer(side, delta);
  const other = otherSide(side);
  const otherUid = ledger.sides[other].uid;
  const myName = ledger.sides[side].displayName;

  const entry: Entry = {
    ...content,
    ledgerId,
    memberUids: ledger.memberUids,
    deltaMinor: delta,
    state: auto ? "confirmed" : "pending",
    version: 1,
    contentHash: hash,
    proposedBy: side,
    proposedByUid: uid,
    awaitingSide: auto ? null : other,
    autoConfirmed: auto && shared,
    reversedBy: null,
    reversalPendingId: null,
  };

  let chain: {confirmedSeq: number | null; chainHash: string | null} = {
    confirmedSeq: null,
    chainHash: null,
  };
  if (auto) {
    chain = commitToLedger(tx, ledgerRef, ledger, entry, 0);
  } else {
    tx.update(ledgerRef, {
      pendingCount: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
      lastEntryAt: FieldValue.serverTimestamp(),
    });
  }

  tx.set(entryRef, {
    ...entry,
    ...chain,
    dispute: null,
    rejection: null,
    confirmation: auto ? {
      version: 1,
      contentHash: hash,
      uid,
      via: shared ? "againstProposer" : "private",
      at: FieldValue.serverTimestamp(),
    } : null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  addRevision(tx, entryRef, entry, uid);
  addEvent(tx, ledgerRef, entry, entryId, "created", uid);
  if (auto) addEvent(tx, ledgerRef, entry, entryId, "confirmed", uid);

  if (shared && otherUid) {
    if (!auto) {
      tx.set(
        inboxRef(otherUid, entryId),
        inboxItem("confirmEntry", entry, entryId, other, myName)
      );
    }
    notices.push({
      uid: otherUid,
      setting: auto ? "statusChanges" : "newDebtRequests",
      type: auto ? "entryRecorded" : "confirmRequest",
      title: auto ? "Yeni kayıt" : "Onayınız bekleniyor",
      message: describe(other, entry, myName, !auto),
      ledgerId,
      entryId,
    });
  }
  return {entryId, state: entry.state, version: 1};
}

/**
 * Kayıt kişiyle ortak defter ya da uygulaması olmayan biri için özel defter
 * açar. Aynı iki kişi için her zaman aynı defter döner.
 */
export const createLedger = onCall<unknown>(OPTS, async (req) => {
  const uid = requireUid(req);
  const input = parse(CreateLedgerInput, req.data);
  const me = await db.collection("users").doc(uid).get();
  const mySide = {uid, displayName: displayNameOf(me)};

  if ("privateName" in input) {
    const autoId = db.collection("ledgers").doc().id;
    const ref = db.collection("ledgers").doc(`v_${autoId}`);
    await ref.set(newLedger(
      "private",
      mySide,
      {uid: null, displayName: input.privateName},
      [uid]
    ));
    return {ledgerId: ref.id, created: true};
  }

  const otherUid = input.counterpartyUid;
  if (otherUid === uid) {
    fail("invalid-argument", "Kendinizle defter açamazsınız.");
  }
  const other = await db.collection("users").doc(otherUid).get();
  if (!other.exists) fail("not-found", "Kullanıcı bulunamadı.");

  const ledgerId = `p_${[uid, otherUid].sort().join("_")}`;
  const ref = db.collection("ledgers").doc(ledgerId);
  const created = await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return false;
    tx.set(ref, newLedger(
      "shared",
      mySide,
      {uid: otherUid, displayName: displayNameOf(other)},
      [uid, otherUid]
    ));
    return true;
  });
  return {ledgerId, created};
});

/**
 * Borç ya da ödeme kaydı. Kaydı girenin lehineyse karşı tarafın onayını
 * bekler; aleyhineyse ya da defter özelse hemen bakiyeye işlenir.
 * Aynı entryId ile tekrar çağrı aynı sonucu döner.
 */
export const createEntry = onCall<unknown>(OPTS, async (req) => {
  const uid = requireUid(req);
  const input = parse(CreateEntryInput, req.data);
  if (input.dueOn && input.dueOn < input.occurredOn) {
    fail("invalid-argument", "Vade, işlem tarihinden önce olamaz.");
  }
  if (input.linkedEntryId && input.kind !== "payment") {
    fail("invalid-argument", "Yalnızca ödeme bir borca bağlanabilir.");
  }
  const {ledgerRef, entryRef} = refsFor(input.ledgerId, input.entryId);
  const notices: Notice[] = [];

  const result = await db.runTransaction(async (tx) => {
    const {ledger, side} = await readLedger(tx, ledgerRef, uid);
    const existing = await tx.get(entryRef);
    if (existing.exists) {
      if (existing.get("proposedByUid") !== uid) {
        fail("already-exists", "Kayıt kimliği kullanılmış.");
      }
      return {
        entryId: input.entryId,
        state: existing.get("state") as string,
        version: existing.get("version") as number,
      };
    }
    if (input.linkedEntryId) {
      const linked = await tx.get(
        ledgerRef.collection("entries").doc(input.linkedEntryId)
      );
      if (!linked.exists || linked.get("kind") !== "debt") {
        fail("failed-precondition", "Bağlanan borç bulunamadı.");
      }
    }
    const content: EntryContent = {
      kind: input.kind,
      direction: directionFor(side, input.iGave),
      asset: input.asset,
      amountMinor: input.amountMinor,
      occurredOn: input.occurredOn,
      dueOn: input.dueOn,
      description: input.description,
      linkedEntryId: input.linkedEntryId,
    };
    return writeNewEntry(tx, {
      uid,
      side,
      ledger,
      ledgerId: input.ledgerId,
      entryId: input.entryId,
      content,
      notices,
    });
  });

  await deliver(notices);
  return result;
});

/** Bekleyen kaydı karşı taraf onaylar; bakiye ve zincir güncellenir. */
export const confirmEntry = onCall<unknown>(OPTS, async (req) => {
  const uid = requireUid(req);
  const input = parse(ConfirmInput, req.data);
  const {ledgerRef, entryRef} = refsFor(input.ledgerId, input.entryId);
  const notices: Notice[] = [];

  const result = await db.runTransaction(async (tx) => {
    const {ledger, side} = await readLedger(tx, ledgerRef, uid);
    const entry = await readEntry(tx, entryRef);
    if (
      entry.state === "confirmed" &&
      entry.confirmation?.uid === uid &&
      entry.version === input.expectedVersion
    ) {
      return {state: entry.state, version: entry.version};
    }
    assertVersion(entry, input.expectedVersion);
    if (entry.state !== "pending" || entry.awaitingSide !== side) {
      fail("failed-precondition", "Bu kayıt sizin onayınızı beklemiyor.");
    }
    let originalRef: DocumentReference | null = null;
    if (entry.kind === "reversal" && entry.linkedEntryId) {
      originalRef = ledgerRef.collection("entries").doc(entry.linkedEntryId);
      const original = await readEntry(tx, originalRef);
      if (original.state !== "confirmed" || original.reversedBy) {
        fail("failed-precondition", "Düzeltilen kayıt artık geçerli değil.");
      }
    }

    const chain = commitToLedger(tx, ledgerRef, ledger, entry, -1);
    tx.update(entryRef, {
      ...chain,
      state: "confirmed",
      awaitingSide: null,
      confirmation: {
        version: entry.version,
        contentHash: entry.contentHash,
        uid,
        via: "counterparty",
        at: FieldValue.serverTimestamp(),
      },
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (originalRef) {
      tx.update(originalRef, {
        reversedBy: input.entryId,
        reversalPendingId: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    addEvent(tx, ledgerRef, entry, input.entryId, "confirmed", uid);
    tx.delete(inboxRef(uid, input.entryId));
    notices.push({
      uid: entry.proposedByUid,
      setting: "statusChanges",
      type: "entryConfirmed",
      title: "Kayıt onaylandı",
      message: `${ledger.sides[side].displayName} kaydınızı onayladı: ` +
        `${formatMinor(entry.amountMinor, entry.asset)}.`,
      ledgerId: input.ledgerId,
      entryId: input.entryId,
    });
    return {state: "confirmed", version: entry.version};
  });

  await deliver(notices);
  return result;
});

/** Karşı taraf itiraz eder; kayıt düzeltilmek üzere kaydı girene döner. */
export const disputeEntry = onCall<unknown>(OPTS, async (req) => {
  const uid = requireUid(req);
  const input = parse(DisputeInput, req.data);
  const {ledgerRef, entryRef} = refsFor(input.ledgerId, input.entryId);
  const notices: Notice[] = [];

  const result = await db.runTransaction(async (tx) => {
    const {ledger, side} = await readLedger(tx, ledgerRef, uid);
    const entry = await readEntry(tx, entryRef);
    assertVersion(entry, input.expectedVersion);
    if (entry.state !== "pending" || entry.awaitingSide !== side) {
      fail("failed-precondition", "Bu kayıt sizin onayınızı beklemiyor.");
    }
    tx.update(entryRef, {
      state: "disputed",
      awaitingSide: entry.proposedBy,
      dispute: {
        byUid: uid,
        reason: input.reason,
        note: input.note,
        suggestedAmountMinor: input.suggestedAmountMinor,
        at: FieldValue.serverTimestamp(),
      },
      updatedAt: FieldValue.serverTimestamp(),
    });
    addEvent(tx, ledgerRef, entry, input.entryId, "disputed", uid);
    tx.delete(inboxRef(uid, input.entryId));
    const myName = ledger.sides[side].displayName;
    tx.set(
      inboxRef(entry.proposedByUid, input.entryId),
      inboxItem("reviseEntry", entry, input.entryId, entry.proposedBy, myName)
    );
    const reason = DISPUTE_REASONS[input.reason];
    notices.push({
      uid: entry.proposedByUid,
      setting: "statusChanges",
      type: "entryDisputed",
      title: "Kaydınıza itiraz edildi",
      message: `${myName} kaydınıza itiraz etti: ${reason}` +
        (input.note ? ` — “${input.note}”` : "."),
      ledgerId: input.ledgerId,
      entryId: input.entryId,
    });
    return {state: "disputed", version: entry.version};
  });

  await deliver(notices);
  return result;
});

/** Karşı taraf reddeder; kayıt kapanır, bakiyeye hiç işlenmez. */
export const rejectEntry = onCall<unknown>(OPTS, async (req) => {
  const uid = requireUid(req);
  const input = parse(RejectInput, req.data);
  const {ledgerRef, entryRef} = refsFor(input.ledgerId, input.entryId);
  const notices: Notice[] = [];

  const result = await db.runTransaction(async (tx) => {
    const {ledger, side} = await readLedger(tx, ledgerRef, uid);
    const entry = await readEntry(tx, entryRef);
    assertVersion(entry, input.expectedVersion);
    if (entry.state !== "pending" || entry.awaitingSide !== side) {
      fail("failed-precondition", "Bu kayıt sizin onayınızı beklemiyor.");
    }
    tx.update(entryRef, {
      state: "rejected",
      awaitingSide: null,
      rejection: {
        byUid: uid,
        reason: input.reason,
        note: input.note,
        at: FieldValue.serverTimestamp(),
      },
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(ledgerRef, {
      pendingCount: FieldValue.increment(-1),
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (entry.kind === "reversal" && entry.linkedEntryId) {
      tx.update(ledgerRef.collection("entries").doc(entry.linkedEntryId), {
        reversalPendingId: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    addEvent(tx, ledgerRef, entry, input.entryId, "rejected", uid);
    tx.delete(inboxRef(uid, input.entryId));
    notices.push({
      uid: entry.proposedByUid,
      setting: "statusChanges",
      type: "entryRejected",
      title: "Kayıt reddedildi",
      message: `${ledger.sides[side].displayName} kaydınızı reddetti: ` +
        `${formatMinor(entry.amountMinor, entry.asset)}.`,
      ledgerId: input.ledgerId,
      entryId: input.entryId,
    });
    return {state: "rejected", version: entry.version};
  });

  await deliver(notices);
  return result;
});

/**
 * Kaydı giren, bekleyen ya da itiraz edilen kaydı düzeltir. Yeni sürüm
 * oluşur ve karşı tarafın önceki onay görünümü geçersizleşir.
 */
export const reviseEntry = onCall<unknown>(OPTS, async (req) => {
  const uid = requireUid(req);
  const input = parse(ReviseInput, req.data);
  const {ledgerRef, entryRef} = refsFor(input.ledgerId, input.entryId);
  const notices: Notice[] = [];

  const result = await db.runTransaction(async (tx) => {
    const {ledger, side} = await readLedger(tx, ledgerRef, uid);
    const entry = await readEntry(tx, entryRef);
    assertVersion(entry, input.expectedVersion);
    if (entry.proposedByUid !== uid) {
      fail("permission-denied", "Yalnızca kaydı giren düzeltebilir.");
    }
    if (entry.state !== "pending" && entry.state !== "disputed") {
      fail("failed-precondition", "Bu kayıt artık düzeltilemez.");
    }
    if (entry.kind === "reversal") {
      fail("failed-precondition", "Düzeltme kaydının tutarı değiştirilemez.");
    }
    const content: EntryContent = {
      kind: entry.kind,
      direction: entry.direction,
      asset: input.asset ?? entry.asset,
      amountMinor: input.amountMinor ?? entry.amountMinor,
      occurredOn: input.occurredOn ?? entry.occurredOn,
      dueOn: input.dueOn !== undefined ? input.dueOn : entry.dueOn,
      description: input.description ?? entry.description,
      linkedEntryId: entry.linkedEntryId,
    };
    if (content.dueOn && content.dueOn < content.occurredOn) {
      fail("invalid-argument", "Vade, işlem tarihinden önce olamaz.");
    }
    const version = entry.version + 1;
    const other = otherSide(side);
    const revised: Entry = {
      ...entry,
      ...content,
      deltaMinor: deltaFor(content.direction, content.amountMinor),
      version,
      contentHash: contentHash(input.ledgerId, input.entryId, content, version),
      state: "pending",
      awaitingSide: other,
    };
    tx.update(entryRef, {
      ...content,
      deltaMinor: revised.deltaMinor,
      version,
      contentHash: revised.contentHash,
      state: "pending",
      awaitingSide: other,
      dispute: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    addRevision(tx, entryRef, revised, uid);
    addEvent(tx, ledgerRef, revised, input.entryId, "revised", uid);
    tx.delete(inboxRef(uid, input.entryId));
    const otherUid = ledger.sides[other].uid;
    const myName = ledger.sides[side].displayName;
    if (otherUid) {
      tx.set(
        inboxRef(otherUid, input.entryId),
        inboxItem("confirmEntry", revised, input.entryId, other, myName)
      );
      notices.push({
        uid: otherUid,
        setting: "newDebtRequests",
        type: "confirmRequest",
        title: "Kayıt düzeltildi",
        message: `${myName} kaydı düzeltti, onayınızı bekliyor: ` +
          `${formatMinor(revised.amountMinor, revised.asset)}.`,
        ledgerId: input.ledgerId,
        entryId: input.entryId,
      });
    }
    return {state: "pending", version};
  });

  await deliver(notices);
  return result;
});

/** Kaydı giren, onaylanmamış kaydını geri çeker. Bildirim gönderilmez. */
export const cancelEntry = onCall<unknown>(OPTS, async (req) => {
  const uid = requireUid(req);
  const input = parse(CancelInput, req.data);
  const {ledgerRef, entryRef} = refsFor(input.ledgerId, input.entryId);

  return db.runTransaction(async (tx) => {
    const {ledger, side} = await readLedger(tx, ledgerRef, uid);
    const entry = await readEntry(tx, entryRef);
    assertVersion(entry, input.expectedVersion);
    if (entry.proposedByUid !== uid) {
      fail("permission-denied", "Yalnızca kaydı giren geri çekebilir.");
    }
    if (entry.state !== "pending" && entry.state !== "disputed") {
      fail("failed-precondition", "Bu kayıt artık geri çekilemez.");
    }
    tx.update(entryRef, {
      state: "cancelled",
      awaitingSide: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(ledgerRef, {
      pendingCount: FieldValue.increment(-1),
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (entry.kind === "reversal" && entry.linkedEntryId) {
      tx.update(ledgerRef.collection("entries").doc(entry.linkedEntryId), {
        reversalPendingId: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    addEvent(tx, ledgerRef, entry, input.entryId, "cancelled", uid);
    tx.delete(inboxRef(uid, input.entryId));
    const otherUid = ledger.sides[otherSide(side)].uid;
    if (otherUid) tx.delete(inboxRef(otherUid, input.entryId));
    return {state: "cancelled", version: entry.version};
  });
});

/**
 * Onaylanmış kayıt değiştirilmez; düzeltmek için ters kayıt açılır.
 * Ters kayıt da onay ister (aleyhe ise hemen işlenir).
 */
export const reverseEntry = onCall<unknown>(OPTS, async (req) => {
  const uid = requireUid(req);
  const input = parse(ReverseInput, req.data);
  const {ledgerRef, entryRef} = refsFor(input.ledgerId, input.entryId);
  const reversalRef = ledgerRef.collection("entries").doc(input.reversalId);
  const notices: Notice[] = [];

  const result = await db.runTransaction(async (tx) => {
    const {ledger, side} = await readLedger(tx, ledgerRef, uid);
    const existing = await tx.get(reversalRef);
    if (existing.exists) {
      if (existing.get("proposedByUid") !== uid) {
        fail("already-exists", "Kayıt kimliği kullanılmış.");
      }
      return {
        entryId: input.reversalId,
        state: existing.get("state") as string,
        version: existing.get("version") as number,
      };
    }
    const target = await readEntry(tx, entryRef);
    if (target.state !== "confirmed") {
      fail("failed-precondition", "Yalnızca onaylı kayıt düzeltilebilir.");
    }
    if (target.kind === "reversal") {
      fail("failed-precondition", "Düzeltme kaydı tekrar düzeltilemez.");
    }
    if (target.reversedBy || target.reversalPendingId) {
      fail("failed-precondition", "Bu kayıt için zaten bir düzeltme var.");
    }
    const description = input.note ||
      `Düzeltme: ${target.description}`.slice(0, 280);
    const content: EntryContent = {
      kind: "reversal",
      direction: target.direction === "aToB" ? "bToA" : "aToB",
      asset: target.asset,
      amountMinor: target.amountMinor,
      occurredOn: todayIstanbul(),
      dueOn: null,
      description,
      linkedEntryId: input.entryId,
    };
    const written = writeNewEntry(tx, {
      uid,
      side,
      ledger,
      ledgerId: input.ledgerId,
      entryId: input.reversalId,
      content,
      notices,
    });
    tx.update(entryRef, written.state === "confirmed" ? {
      reversedBy: input.reversalId,
      updatedAt: FieldValue.serverTimestamp(),
    } : {
      reversalPendingId: input.reversalId,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return written;
  });

  await deliver(notices);
  return result;
});
