import {createHash} from "node:crypto";

// Bakiye işareti: pozitif bakiye = b tarafı a tarafına borçlu.
// Değer a'dan b'ye geçerse (a borç verdi / a ödeme yaptı) bakiye artar.

export type Side = "a" | "b";
export type Direction = "aToB" | "bToA";
export type EntryKind = "debt" | "payment" | "reversal";
export type EntryState =
  | "pending"
  | "confirmed"
  | "disputed"
  | "rejected"
  | "cancelled";

export interface LedgerSide {
  uid: string | null;
  displayName: string;
  /** Ortak defterde giriş e-postası (karşı taraf kişiyi tanısın diye). */
  email?: string | null;
}

/** Vadesi olan ve henüz kapanmamış borç parçası (bkz. due.ts). */
export interface DueItem {
  entryId: string;
  asset: string;
  /** Borçlu taraf. */
  debtorSide: Side;
  openMinor: number;
  dueOn: string;
  description: string;
}

export interface Ledger {
  mode: "shared" | "private";
  status: "active" | "closed";
  sides: {a: LedgerSide; b: LedgerSide};
  memberUids: string[];
  balances: {[asset: string]: number};
  pendingCount: number;
  head: {seq: number; chainHash: string};
  /** Sunucunun hesapladığı açık vadeler, vadeye göre sıralı. */
  dueItems?: DueItem[];
  dueDates?: string[];
  /** Günlük vade hatırlatmasının en son gönderildiği gün. */
  dueRemindedOn?: string;
  /** Tarafın karşı tarafa gönderdiği son hatırlatma. */
  reminders?: {[side in Side]?: {lastOn: string; kind: string}};
}

export interface EntryContent {
  kind: EntryKind;
  direction: Direction;
  asset: string;
  amountMinor: number;
  occurredOn: string;
  dueOn: string | null;
  description: string;
  linkedEntryId: string | null;
}

export interface Entry extends EntryContent {
  ledgerId: string;
  memberUids: string[];
  deltaMinor: number;
  state: EntryState;
  version: number;
  contentHash: string;
  proposedBy: Side;
  proposedByUid: string;
  awaitingSide: Side | null;
  autoConfirmed: boolean;
  reversedBy: string | null;
  reversalPendingId: string | null;
}

/**
 * Kullanıcının defterdeki tarafını bulur.
 * @param {Ledger} ledger Defter.
 * @param {string} uid Kullanıcı.
 * @return {Side | null} Taraf ya da üye değilse null.
 */
export function sideOf(ledger: Ledger, uid: string): Side | null {
  if (ledger.sides.a.uid === uid) return "a";
  if (ledger.sides.b.uid === uid) return "b";
  return null;
}

/**
 * Karşı tarafı döndürür.
 * @param {Side} side Taraf.
 * @return {Side} Diğer taraf.
 */
export function otherSide(side: Side): Side {
  return side === "a" ? "b" : "a";
}

/**
 * Kaydı girenin bakış açısından yönü defter yönüne çevirir.
 * @param {Side} callerSide Kaydı girenin tarafı.
 * @param {boolean} iGave Değer kaydı girenden çıktı mı (borç verdim,
 *     ödeme yaptım).
 * @return {Direction} Defter yönü.
 */
export function directionFor(callerSide: Side, iGave: boolean): Direction {
  const fromA = callerSide === "a" ? iGave : !iGave;
  return fromA ? "aToB" : "bToA";
}

/**
 * Kaydın bakiyeye etkisi.
 * @param {Direction} direction Yön.
 * @param {number} amountMinor Tutar.
 * @return {number} İşaretli etki.
 */
export function deltaFor(direction: Direction, amountMinor: number): number {
  return direction === "aToB" ? amountMinor : -amountMinor;
}

/**
 * Kayıt, onu girenin aleyhine mi? Aleyhe kayıtlar onay beklemez.
 * @param {Side} proposer Kaydı giren taraf.
 * @param {number} deltaMinor Bakiyeye etki.
 * @return {boolean} Aleyhe ise true.
 */
export function isAgainstProposer(proposer: Side, deltaMinor: number): boolean {
  return proposer === "a" ? deltaMinor < 0 : deltaMinor > 0;
}

/**
 * Bir tarafın gördüğü etki (pozitif = karşı taraf size daha çok borçlu).
 * @param {Side} side Taraf.
 * @param {number} deltaMinor Defter etkisi.
 * @return {number} Tarafın bakış açısından etki.
 */
export function deltaForSide(side: Side, deltaMinor: number): number {
  return side === "a" ? deltaMinor : -deltaMinor;
}

/**
 * Onaylanan içeriğin özeti. Test vektörleri contracts/entry_hash_vectors.json.
 * @param {string} ledgerId Defter.
 * @param {string} entryId Kayıt.
 * @param {EntryContent} c İçerik.
 * @param {number} version Sürüm.
 * @return {string} SHA-256 (hex).
 */
export function contentHash(
  ledgerId: string,
  entryId: string,
  c: EntryContent,
  version: number
): string {
  const fields = [
    "pacta.entry.v1",
    ledgerId,
    entryId,
    c.kind,
    c.direction,
    c.asset,
    c.amountMinor,
    c.occurredOn,
    c.dueOn ?? "",
    c.description.normalize("NFC"),
    c.linkedEntryId ?? "",
    version,
  ];
  return sha256(JSON.stringify(fields));
}

/**
 * Onaylanan kayıtları sıraya bağlar; araya kayıt sokulması fark edilir.
 * @param {string} previous Önceki zincir değeri.
 * @param {string} content Onaylanan içeriğin özeti.
 * @param {number} seq Sıra numarası.
 * @return {string} SHA-256 (hex).
 */
export function chainHash(
  previous: string,
  content: string,
  seq: number
): string {
  return sha256(JSON.stringify([previous, content, seq]));
}

/**
 * @param {string} text Girdi.
 * @return {string} SHA-256 (hex).
 */
function sha256(text: string): string {
  return createHash("sha256").update(text, "utf8").digest("hex");
}

/**
 * İstanbul saatine göre bugünün tarihi.
 * @param {Date} now An.
 * @return {string} YYYY-MM-DD.
 */
export function todayIstanbul(now: Date = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", {timeZone: "Europe/Istanbul"})
    .format(now);
}

/**
 * İstanbul saatine göre saat (0-23).
 * @param {Date} now An.
 * @return {number} Saat.
 */
export function hourIstanbul(now: Date): number {
  return Number(new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Istanbul",
    hour: "2-digit",
    hourCycle: "h23",
  }).format(now));
}

/**
 * @param {string} day YYYY-MM-DD.
 * @param {number} days Eklenecek gün (negatif olabilir).
 * @return {string} YYYY-MM-DD.
 */
export function addDays(day: string, days: number): string {
  const [y, m, d] = day.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + days)).toISOString().slice(0, 10);
}

/**
 * @param {string} value YYYY-MM-DD.
 * @return {boolean} Gerçek bir takvim günü mü.
 */
export function isValidDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [y, m, d] = value.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.getUTCFullYear() === y &&
    date.getUTCMonth() === m - 1 &&
    date.getUTCDate() === d;
}
