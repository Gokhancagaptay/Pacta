import {DocumentData} from "firebase-admin/firestore";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {db, REGION} from "../common/firebase";
import {Direction, DueItem, EntryKind, Side} from "./model";

// Açık vadeler: hangi borcun ne kadarı, hangi tarihte ödenmemiş kaldı.
// Ödemeler önce en eski borcu kapatır (FIFO); bir borca bağlanmış ödeme
// önce o borçtan düşer. Sonuç deftere yazılır; ekranlar ve günlük hatırlatma
// buradan okur.

export const MAX_DUE_ITEMS = 50;

/** Hesap için gereken kayıt alanları. */
export interface DueSource {
  id: string;
  kind: EntryKind;
  direction: Direction;
  asset: string;
  amountMinor: number;
  deltaMinor: number;
  occurredOn: string;
  dueOn: string | null;
  description: string;
  linkedEntryId: string | null;
  reversedBy: string | null;
  confirmedSeq: number;
}

/**
 * Onaylı kayıtlardan açık vadeli borç parçalarını çıkarır.
 * @param {DueSource[]} confirmed Onaylı kayıtlar.
 * @return {DueItem[]} Vadeye göre sıralı açık parçalar.
 */
export function openDueItems(confirmed: DueSource[]): DueItem[] {
  const items: DueItem[] = [];
  const assets = new Set(confirmed.map((e) => e.asset));
  for (const asset of assets) {
    const inAsset = confirmed.filter((e) => e.asset === asset);
    const balance = inAsset.reduce((sum, e) => sum + e.deltaMinor, 0);
    if (balance === 0) continue;
    // Pozitif bakiye: b, a'ya borçlu; açık borçlar a'dan b'ye verilenlerdir.
    const owed: Direction = balance > 0 ? "aToB" : "bToA";
    const debtorSide: Side = balance > 0 ? "b" : "a";

    const paidByLink = new Map<string, number>();
    for (const e of inAsset) {
      if (
        e.kind === "payment" && e.linkedEntryId &&
        e.direction !== owed && !e.reversedBy
      ) {
        paidByLink.set(
          e.linkedEntryId,
          (paidByLink.get(e.linkedEntryId) ?? 0) + e.amountMinor
        );
      }
    }

    // Açık kalan tutar en yeni borçlardadır; eskiler önce kapanmıştır.
    const debts = inAsset
      .filter((e) => e.kind === "debt" && e.direction === owed && !e.reversedBy)
      .sort((x, y) =>
        y.occurredOn.localeCompare(x.occurredOn) ||
        y.confirmedSeq - x.confirmedSeq);
    let remaining = Math.abs(balance);
    for (const d of debts) {
      if (remaining <= 0) break;
      const capacity = Math.max(0, d.amountMinor - (paidByLink.get(d.id) ?? 0));
      const open = Math.min(remaining, capacity);
      remaining -= open;
      if (open > 0 && d.dueOn) {
        items.push({
          entryId: d.id,
          asset,
          debtorSide,
          openMinor: open,
          dueOn: d.dueOn,
          description: d.description,
        });
      }
    }
  }
  return items
    .sort((x, y) =>
      x.dueOn.localeCompare(y.dueOn) || x.entryId.localeCompare(y.entryId))
    .slice(0, MAX_DUE_ITEMS);
}

/**
 * @param {string} id Kayıt kimliği.
 * @param {DocumentData} d Kayıt.
 * @return {DueSource} Hesap girdisi.
 */
function toSource(id: string, d: DocumentData): DueSource {
  return {
    id,
    kind: d.kind,
    direction: d.direction,
    asset: d.asset,
    amountMinor: d.amountMinor,
    deltaMinor: d.deltaMinor,
    occurredOn: d.occurredOn,
    dueOn: d.dueOn ?? null,
    description: d.description ?? "",
    linkedEntryId: d.linkedEntryId ?? null,
    reversedBy: d.reversedBy ?? null,
    confirmedSeq: d.confirmedSeq ?? 0,
  };
}

/**
 * Defterin açık vadelerini yeniden hesaplayıp yazar.
 * @param {string} ledgerId Defter.
 */
export async function recomputeDue(ledgerId: string): Promise<void> {
  const ledgerRef = db.collection("ledgers").doc(ledgerId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(
      ledgerRef.collection("entries").where("state", "==", "confirmed")
    );
    const items = openDueItems(snap.docs.map((d) => toSource(d.id, d.data())));
    tx.update(ledgerRef, {
      dueItems: items,
      dueDates: [...new Set(items.map((i) => i.dueOn))],
    });
  });
}

/**
 * Yalnızca onaylı kümeyi değiştiren yazımlar vadeyi etkiler.
 * @param {DocumentData | undefined} before Önceki hâl.
 * @param {DocumentData | undefined} after Sonraki hâl.
 * @return {boolean} Yeniden hesap gerekir mi.
 */
export function affectsDue(
  before: DocumentData | undefined,
  after: DocumentData | undefined
): boolean {
  const was = before?.state === "confirmed";
  const is = after?.state === "confirmed";
  if (!was && !is) return false;
  const reversedBefore = before?.reversedBy ?? null;
  const reversedAfter = after?.reversedBy ?? null;
  return was !== is || reversedBefore !== reversedAfter;
}

export const onLedgerEntryWritten = onDocumentWritten(
  {document: "ledgers/{ledgerId}/entries/{entryId}", region: REGION},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!affectsDue(before, after)) return;
    await recomputeDue(event.params.ledgerId);
  }
);
