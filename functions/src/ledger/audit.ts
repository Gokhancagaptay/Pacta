import {DocumentData} from "firebase-admin/firestore";
import {db} from "../common/firebase";
import {EntryContent, Side, chainHash, contentHash, deltaFor} from "./model";

// Bakiye ve zincir tutarlılık denetimi (salt okunur). Komutların deftere
// yazdıklarının birbiriyle tutarlı olduğunu yeniden hesaplayarak doğrular:
//
// - balances[birim] = o birimdeki onaylı kayıtların deltaMinor toplamı.
//   Ters kaydı yapılmış kayıt onaylı kalır ve toplama girer; ters kaydı da
//   onaylıdır, ikisi birbirini sıfırlar.
// - pendingCount = "pending" ve "disputed" kayıt sayısı. İtiraz edilen
//   kayıt kaydı girenin düzeltmesini bekler; sayaçtan düşmez.
// - Onaylı kayıtların confirmedSeq değerleri 1..head.seq arasında boşluksuz
//   ve tekildir; onaylanmamış kayıtta sıra ve zincir yoktur.
// - chainHash = sha256([önceki zincir, contentHash, seq]); ilk önceki
//   değer "". Sıra onay sırasıdır, oluşturma sırası değil.
// - contentHash kaydın güncel sürümünün özetidir; onay yalnızca güncel
//   sürüme verilir, bu yüzden confirmation da aynı sürümü ve özeti taşır.
// - deltaMinor özete dahil değildir; yön ve tutardan yeniden hesaplanır.
// - Ters kayıt bağları iki yönden tutarlıdır (reversedBy,
//   reversalPendingId, linkedEntryId).
//
// Özel defterdeki kaydın web yanıtı (webConfirmation) kaydın durumunu ve
// bakiyeyi değiştirmez; denetlenmez. Sorunlarda kişisel veri yoktur:
// yalnızca kod, kimlikler, birim, sıra ve uyuşmayan sayılar.

/** Sorun kodları. Değişmez: günlük aramaları ve uyarılar bunlara bağlı. */
export type AuditCode =
  | "LEDGER_MISSING"
  | "LEDGER_MALFORMED"
  | "ENTRY_MALFORMED"
  | "BALANCE_MISMATCH"
  | "PENDING_COUNT_MISMATCH"
  | "DELTA_MISMATCH"
  | "CONTENT_HASH_MISMATCH"
  | "CONFIRMATION_MISMATCH"
  | "AWAITING_SIDE_MISMATCH"
  | "SEQ_MISSING"
  | "SEQ_ON_UNCONFIRMED"
  | "SEQ_DUPLICATE"
  | "SEQ_GAP"
  | "HEAD_SEQ_MISMATCH"
  | "CHAIN_HASH_MISMATCH"
  | "HEAD_CHAIN_MISMATCH"
  | "LINK_TARGET_MISSING"
  | "REVERSAL_CONTENT_MISMATCH"
  | "REVERSAL_LINK_MISMATCH"
  | "REVERSED_BY_DANGLING"
  | "REVERSAL_PENDING_DANGLING";

/** Bir tutarsızlık. Kişisel veri (ad, e-posta, açıklama) içermez. */
export interface AuditProblem {
  code: AuditCode;
  ledgerId: string;
  entryId?: string;
  /** Bağlantılı kayıt (ters kayıt, düzeltilen kayıt, aynı sıradaki kayıt). */
  relatedEntryId?: string;
  asset?: string;
  /** Bozuk ya da uyuşmayan alanın adı. */
  field?: string;
  seq?: number;
  /** Boşluğun son sırası (SEQ_GAP). */
  seqTo?: number;
  expected?: number | string | null;
  actual?: number | string | null;
}

/** Denetlenecek belge: kimliği ve verisi. */
export interface AuditDoc {
  id: string;
  data: DocumentData;
}

const STATES = ["pending", "confirmed", "disputed", "rejected", "cancelled"];
const KINDS = ["debt", "payment", "reversal"];
const DIRECTIONS = ["aToB", "bToA"];
const CONTENT_FIELDS = ["kind", "direction", "asset", "amountMinor",
  "occurredOn", "dueOn", "description", "linkedEntryId", "version"];

/** Doğrulanmış kayıt alanları; bozuk kayıtta yalnızca okunabilenler. */
interface Row {
  id: string;
  raw: DocumentData;
  state: string | null;
  asset: string | null;
  deltaMinor: number | null;
  /** İçerik eksiksizse özet yeniden hesaplanabilir. */
  content: EntryContent | null;
  version: number | null;
  proposedBy: Side | null;
}

/**
 * @param {unknown} v Değer.
 * @return {boolean} Güvenli tamsayı mı.
 */
function isInt(v: unknown): v is number {
  return typeof v === "number" && Number.isSafeInteger(v);
}

/**
 * @param {unknown} v Değer.
 * @return {boolean} Metin ya da boş (null/undefined) mı.
 */
function isOptionalString(v: unknown): boolean {
  return v === null || v === undefined || typeof v === "string";
}

/**
 * @param {unknown} v Değer.
 * @return {string | null} Boş olmayan metin ya da null.
 */
function idOrNull(v: unknown): string | null {
  return typeof v === "string" && v !== "" ? v : null;
}

/**
 * Kaydın alanlarını okur; ilk bozuk alanı bildirir.
 * @param {AuditDoc} doc Kayıt.
 * @return {object} Satır ve bozuk alan (yoksa null).
 */
function readRow(doc: AuditDoc): {row: Row; bad: string | null} {
  const d = doc.data ?? {};
  const state = STATES.includes(d.state) ? d.state as string : null;
  const asset = typeof d.asset === "string" && d.asset ? d.asset : null;
  const deltaMinor = isInt(d.deltaMinor) ? d.deltaMinor : null;
  const version = isInt(d.version) && d.version >= 1 ? d.version : null;
  const proposedBy = d.proposedBy === "a" || d.proposedBy === "b" ?
    d.proposedBy as Side : null;
  const checks: [string, boolean][] = [
    ["state", state !== null],
    ["kind", KINDS.includes(d.kind)],
    ["direction", DIRECTIONS.includes(d.direction)],
    ["asset", asset !== null],
    ["amountMinor", isInt(d.amountMinor) && d.amountMinor > 0],
    ["deltaMinor", deltaMinor !== null],
    ["occurredOn", typeof d.occurredOn === "string"],
    ["dueOn", isOptionalString(d.dueOn)],
    ["description", typeof d.description === "string"],
    ["linkedEntryId", isOptionalString(d.linkedEntryId)],
    ["version", version !== null],
    ["contentHash", typeof d.contentHash === "string"],
    ["proposedBy", proposedBy !== null],
    ["awaitingSide", [null, undefined, "a", "b"].includes(d.awaitingSide)],
    ["reversedBy", isOptionalString(d.reversedBy)],
    ["reversalPendingId", isOptionalString(d.reversalPendingId)],
  ];
  const failed = checks.filter(([, ok]) => !ok).map(([name]) => name);
  // Özet yalnızca içerik alanları ve sürüm sağlamsa yeniden hesaplanır.
  const contentOk = !failed.some((f) => CONTENT_FIELDS.includes(f));
  const content: EntryContent | null = contentOk ? {
    kind: d.kind,
    direction: d.direction,
    asset: d.asset,
    amountMinor: d.amountMinor,
    occurredOn: d.occurredOn,
    dueOn: d.dueOn ?? null,
    description: d.description,
    linkedEntryId: d.linkedEntryId ?? null,
  } : null;
  return {
    row: {
      id: doc.id, raw: d, state, asset, deltaMinor, content, version,
      proposedBy,
    },
    bad: failed[0] ?? null,
  };
}

/**
 * Defteri kayıtlarıyla birlikte denetler. Saf fonksiyondur: okumaz,
 * yazmaz; bozuk veride hata fırlatmaz, sorun olarak bildirir.
 * @param {AuditDoc} ledger Defter belgesi.
 * @param {AuditDoc[]} entries Defterin tüm kayıtları.
 * @return {AuditProblem[]} Sorunlar (tutarlıysa boş).
 */
export function auditLedger(
  ledger: AuditDoc,
  entries: AuditDoc[]
): AuditProblem[] {
  const ledgerId = ledger.id;
  const problems: AuditProblem[] = [];
  const add = (p: Omit<AuditProblem, "ledgerId">) =>
    problems.push({ledgerId, ...p});
  const l = ledger.data ?? {};

  const rows: Row[] = [];
  for (const doc of [...entries].sort((x, y) => x.id.localeCompare(y.id))) {
    const {row, bad} = readRow(doc);
    if (bad) add({code: "ENTRY_MALFORMED", entryId: doc.id, field: bad});
    rows.push(row);
  }
  const byId = new Map(rows.map((r) => [r.id, r]));

  checkEntries(rows, ledgerId, add);
  checkBalances(l, rows, add);
  checkPendingCount(l, rows, add);
  checkChain(l, rows, add);
  checkLinks(rows, byId, add);
  return problems;
}

type Add = (p: Omit<AuditProblem, "ledgerId">) => void;

/**
 * Kayıt başına denetimler: etki, içerik özeti, onay kaydı, bekleyen taraf.
 * @param {Row[]} rows Kayıtlar.
 * @param {string} ledgerId Defter.
 * @param {Add} add Sorun ekler.
 */
function checkEntries(rows: Row[], ledgerId: string, add: Add) {
  for (const r of rows) {
    const d = r.raw;
    if (r.content && r.deltaMinor !== null) {
      const expected = deltaFor(r.content.direction, r.content.amountMinor);
      if (expected !== r.deltaMinor) {
        add({code: "DELTA_MISMATCH", entryId: r.id, expected,
          actual: r.deltaMinor});
      }
    }
    if (r.content && r.version !== null && typeof d.contentHash === "string") {
      const expected = contentHash(ledgerId, r.id, r.content, r.version);
      if (expected !== d.contentHash) {
        add({code: "CONTENT_HASH_MISMATCH", entryId: r.id});
      }
    }
    if (r.state === "confirmed") {
      // Onay, kaydın güncel sürümüne ve özetine verilmiş olmalı.
      const c = d.confirmation;
      if (
        !c || typeof c !== "object" || c.version !== d.version ||
        c.contentHash !== d.contentHash
      ) {
        add({code: "CONFIRMATION_MISMATCH", entryId: r.id});
      }
    }
    if (r.state && r.proposedBy) {
      // Bekleyen: karşı taraf; itiraz: kaydı giren; diğerleri: kimse.
      const expected = r.state === "pending" ?
        (r.proposedBy === "a" ? "b" : "a") :
        r.state === "disputed" ? r.proposedBy : null;
      const actual = d.awaitingSide ?? null;
      if (actual !== expected) {
        add({code: "AWAITING_SIDE_MISMATCH", entryId: r.id, expected,
          actual: typeof actual === "string" ? actual : null});
      }
    }
  }
}

/**
 * Birim başına bakiye = onaylı kayıtların etkisi toplamı.
 * @param {DocumentData} l Defter.
 * @param {Row[]} rows Kayıtlar.
 * @param {Add} add Sorun ekler.
 */
function checkBalances(l: DocumentData, rows: Row[], add: Add) {
  let balances: {[asset: string]: unknown} = {};
  if (l.balances && typeof l.balances === "object") {
    balances = l.balances;
  } else {
    add({code: "LEDGER_MALFORMED", field: "balances"});
  }
  const sums = new Map<string, number>();
  for (const r of rows) {
    if (r.state !== "confirmed" || !r.asset || r.deltaMinor === null) continue;
    sums.set(r.asset, (sums.get(r.asset) ?? 0) + r.deltaMinor);
  }
  const assets = [...new Set([...Object.keys(balances), ...sums.keys()])]
    .sort();
  for (const asset of assets) {
    const expected = sums.get(asset) ?? 0;
    const stored = balances[asset];
    const actual = stored === undefined ? 0 : stored;
    if (actual !== expected) {
      add({code: "BALANCE_MISMATCH", asset, expected,
        actual: typeof actual === "number" ? actual : null});
    }
  }
}

/**
 * Bekleyen sayacı = yanıt bekleyen (bekleyen ya da itiraz edilen) kayıtlar.
 * @param {DocumentData} l Defter.
 * @param {Row[]} rows Kayıtlar.
 * @param {Add} add Sorun ekler.
 */
function checkPendingCount(l: DocumentData, rows: Row[], add: Add) {
  const expected = rows
    .filter((r) => r.state === "pending" || r.state === "disputed").length;
  if (!isInt(l.pendingCount)) {
    add({code: "LEDGER_MALFORMED", field: "pendingCount"});
    return;
  }
  if (l.pendingCount !== expected) {
    add({code: "PENDING_COUNT_MISMATCH", expected, actual: l.pendingCount});
  }
}

/**
 * Sıra numaraları, kayıt zinciri ve defter başı.
 * @param {DocumentData} l Defter.
 * @param {Row[]} rows Kayıtlar.
 * @param {Add} add Sorun ekler.
 */
function checkChain(l: DocumentData, rows: Row[], add: Add) {
  const bySeq = new Map<number, Row[]>();
  for (const r of rows) {
    const seq = r.raw.confirmedSeq;
    const chain = r.raw.chainHash;
    if (r.state !== "confirmed") {
      // Bozuk durumlu kayıt ENTRY_MALFORMED olarak zaten bildirildi.
      const hasChain = (seq !== null && seq !== undefined) ||
        (chain !== null && chain !== undefined);
      if (r.state && hasChain) {
        add({code: "SEQ_ON_UNCONFIRMED", entryId: r.id,
          actual: isInt(seq) ? seq : null});
      }
      continue;
    }
    // Zincir değeri eksikse halka denetiminde CHAIN_HASH_MISMATCH olur.
    if (!isInt(seq) || seq < 1) {
      add({code: "SEQ_MISSING", entryId: r.id});
      continue;
    }
    bySeq.set(seq, [...(bySeq.get(seq) ?? []), r]);
  }

  const seqs = [...bySeq.keys()].sort((x, y) => x - y);
  let previous = 0;
  for (const seq of seqs) {
    if (seq > previous + 1) {
      add({code: "SEQ_GAP", seq: previous + 1, seqTo: seq - 1});
    }
    previous = seq;
    const same = bySeq.get(seq) as Row[];
    for (const extra of same.slice(1)) {
      add({code: "SEQ_DUPLICATE", seq, entryId: extra.id,
        relatedEntryId: same[0].id});
    }
    // Her halka, önceki halkanın kayıtlı değerine göre doğrulanır: bozulan
    // halka ve ondan sonraki halka bildirilir, zincirin geri kalanı değil.
    const before = seq === 1 ? [] : bySeq.get(seq - 1);
    if (!before || before.length > 1) continue;
    const prevHash = seq === 1 ? "" : before[0].raw.chainHash as string;
    for (const r of same) {
      if (typeof r.raw.contentHash !== "string") continue;
      if (chainHash(prevHash, r.raw.contentHash, seq) !== r.raw.chainHash) {
        add({code: "CHAIN_HASH_MISMATCH", entryId: r.id, seq});
      }
    }
  }

  const head = l.head;
  if (
    !head || typeof head !== "object" || !isInt(head.seq) || head.seq < 0 ||
    typeof head.chainHash !== "string"
  ) {
    add({code: "LEDGER_MALFORMED", field: "head"});
    return;
  }
  const top = seqs.length > 0 ? seqs[seqs.length - 1] : 0;
  if (head.seq !== top) {
    add({code: "HEAD_SEQ_MISMATCH", expected: top, actual: head.seq});
  }
  const atHead = head.seq === 0 ? null : bySeq.get(head.seq);
  if (head.seq === 0 || atHead?.length === 1) {
    const expected = atHead ? atHead[0].raw.chainHash : "";
    if (head.chainHash !== expected) {
      add({code: "HEAD_CHAIN_MISMATCH", seq: head.seq});
    }
  }
}

/**
 * Ters kayıt ve bağlı ödeme bağları.
 * @param {Row[]} rows Kayıtlar.
 * @param {Map<string, Row>} byId Kimliğe göre kayıtlar.
 * @param {Add} add Sorun ekler.
 */
function checkLinks(rows: Row[], byId: Map<string, Row>, add: Add) {
  const open = (r: Row) => r.state === "pending" || r.state === "disputed";
  for (const r of rows) {
    const d = r.raw;
    const linked = idOrNull(d.linkedEntryId);
    if (d.kind === "payment" && linked && !byId.has(linked)) {
      add({code: "LINK_TARGET_MISSING", entryId: r.id,
        relatedEntryId: linked});
    }
    if (d.kind === "reversal") {
      const target = linked ? byId.get(linked) : undefined;
      if (!linked || !target) {
        add({code: "LINK_TARGET_MISSING", entryId: r.id,
          ...(linked ? {relatedEntryId: linked} : {})});
      } else {
        checkReversal(r, target, add);
      }
    }

    const reversedBy = idOrNull(d.reversedBy);
    const pendingId = idOrNull(d.reversalPendingId);
    if (reversedBy) {
      const rev = byId.get(reversedBy);
      if (
        !rev || rev.raw.kind !== "reversal" ||
        rev.raw.linkedEntryId !== r.id || rev.state !== "confirmed" ||
        r.state !== "confirmed"
      ) {
        add({code: "REVERSED_BY_DANGLING", entryId: r.id,
          relatedEntryId: reversedBy});
      }
    }
    if (pendingId) {
      const rev = byId.get(pendingId);
      if (
        reversedBy || !rev || rev.raw.kind !== "reversal" ||
        rev.raw.linkedEntryId !== r.id || !open(rev)
      ) {
        add({code: "REVERSAL_PENDING_DANGLING", entryId: r.id,
          relatedEntryId: pendingId});
      }
    }
  }
}

/**
 * Ters kayıt, düzelttiği kaydın tersi olmalı ve durumu o kayıtta
 * görünmeli: onaylıysa reversedBy, açıksa reversalPendingId; reddedilen ya
 * da geri çekilen ters kayıt hiçbirinde kalmaz.
 * @param {Row} r Ters kayıt.
 * @param {Row} target Düzeltilen kayıt.
 * @param {Add} add Sorun ekler.
 */
function checkReversal(r: Row, target: Row, add: Add) {
  const d = r.raw;
  const t = target.raw;
  const field = t.kind === "reversal" ? "kind" :
    t.direction === d.direction ? "direction" :
      t.asset !== d.asset ? "asset" :
        t.amountMinor !== d.amountMinor ? "amountMinor" : null;
  if (field) {
    add({code: "REVERSAL_CONTENT_MISMATCH", entryId: r.id,
      relatedEntryId: target.id, field});
  }
  const reversedBy = idOrNull(t.reversedBy);
  const pendingId = idOrNull(t.reversalPendingId);
  let field2: string | null = null;
  if (r.state === "confirmed" && reversedBy !== r.id) {
    field2 = "reversedBy";
  } else if (
    (r.state === "pending" || r.state === "disputed") && pendingId !== r.id
  ) {
    field2 = "reversalPendingId";
  } else if (r.state === "rejected" || r.state === "cancelled") {
    if (reversedBy === r.id) field2 = "reversedBy";
    else if (pendingId === r.id) field2 = "reversalPendingId";
  }
  if (field2) {
    add({code: "REVERSAL_LINK_MISMATCH", entryId: r.id,
      relatedEntryId: target.id, field: field2});
  }
}

/** Saklanan bir defterin denetim sonucu. */
export type StoredAudit =
  | {status: "missing"}
  | {status: "tooLarge"; entriesRead: number}
  | {status: "audited"; entriesRead: number; problems: AuditProblem[]};

/**
 * Defteri ve kayıtlarını salt okunur bir transaction'da (tutarlı tek an)
 * okuyup denetler. Hiçbir şey yazmaz; transaction kilit almaz, komutları
 * bekletmez. Kayıt sayısı sınırı aşan defter kısmen denetlenmez (bakiye ve
 * zincir tüm kayıtları ister), atlanır.
 * @param {string} ledgerId Defter.
 * @param {number} maxEntries Okunacak en fazla kayıt.
 * @return {Promise<StoredAudit>} Sonuç.
 */
export async function auditStoredLedger(
  ledgerId: string,
  maxEntries: number
): Promise<StoredAudit> {
  const ref = db.collection("ledgers").doc(ledgerId);
  return db.runTransaction(async (tx): Promise<StoredAudit> => {
    const snap = await tx.get(ref);
    const entries = await tx.get(ref.collection("entries")
      .limit(maxEntries + 1));
    if (entries.size > maxEntries) {
      return {status: "tooLarge", entriesRead: entries.size};
    }
    if (!snap.exists) {
      // Defter belgesi yok ama kayıtları duruyor: yarım kalmış silme.
      return entries.empty ? {status: "missing"} : {
        status: "audited",
        entriesRead: entries.size,
        problems: [{code: "LEDGER_MISSING", ledgerId}],
      };
    }
    return {
      status: "audited",
      entriesRead: entries.size,
      problems: auditLedger(
        {id: ledgerId, data: snap.data() ?? {}},
        entries.docs.map((d) => ({id: d.id, data: d.data()}))
      ),
    };
  }, {readOnly: true});
}
