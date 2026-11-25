// Açık vade hesabı (FIFO) — saf fonksiyon, emulator gerekmez.
const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {affectsDue, openDueItems} = require("../lib/ledger/due.js");

let seq = 0;
const entry = (id, fields) => ({
  id,
  kind: "debt",
  direction: "aToB",
  asset: "TRY",
  occurredOn: "2026-09-01",
  dueOn: null,
  description: "",
  linkedEntryId: null,
  reversedBy: null,
  confirmedSeq: ++seq,
  ...fields,
  deltaMinor: (fields.direction ?? "aToB") === "aToB" ?
    fields.amountMinor : -fields.amountMinor,
});

describe("openDueItems", () => {
  it("vadeli borç açık kalır", () => {
    const items = openDueItems([
      entry("e1",
        {amountMinor: 1000, dueOn: "2026-10-01", description: "Kira"}),
    ]);
    assert.deepEqual(items, [{
      entryId: "e1", asset: "TRY", debtorSide: "b", openMinor: 1000,
      dueOn: "2026-10-01", description: "Kira",
    }]);
  });

  it("ödeme önce en eski borcu kapatır", () => {
    const items = openDueItems([
      entry("e1", {amountMinor: 1000, occurredOn: "2026-09-01",
        dueOn: "2026-09-10"}),
      entry("e2", {amountMinor: 500, occurredOn: "2026-09-05",
        dueOn: "2026-09-20"}),
      entry("p1", {kind: "payment", direction: "bToA", amountMinor: 800}),
    ]);
    assert.deepEqual(
      items.map((i) => [i.entryId, i.openMinor]),
      [["e1", 200], ["e2", 500]]);
  });

  it("borca bağlı ödeme o borçtan düşer", () => {
    const items = openDueItems([
      entry("e1", {amountMinor: 1000, occurredOn: "2026-09-01",
        dueOn: "2026-09-10"}),
      entry("e2", {amountMinor: 1000, occurredOn: "2026-09-05",
        dueOn: "2026-09-20"}),
      entry("p1", {kind: "payment", direction: "bToA", amountMinor: 1000,
        linkedEntryId: "e2"}),
    ]);
    assert.deepEqual(
      items.map((i) => [i.entryId, i.openMinor]),
      [["e1", 1000]]);
  });

  it("vadesiz borç kalanı tüketir ama listelenmez", () => {
    const items = openDueItems([
      entry("e1", {amountMinor: 1000, occurredOn: "2026-09-01",
        dueOn: "2026-09-10"}),
      entry("e2", {amountMinor: 700, occurredOn: "2026-09-05"}),
      entry("p1", {kind: "payment", direction: "bToA", amountMinor: 900}),
    ]);
    assert.deepEqual(
      items.map((i) => [i.entryId, i.openMinor]), [["e1", 100]]);
  });

  it("ters kayıtla düzeltilen borç ve denk hesap vade üretmez", () => {
    assert.deepEqual(openDueItems([
      entry("e1", {amountMinor: 1000, dueOn: "2026-09-10", reversedBy: "r1"}),
      entry("r1", {kind: "reversal", direction: "bToA", amountMinor: 1000,
        linkedEntryId: "e1"}),
    ]), []);
    assert.deepEqual(openDueItems([
      entry("e1", {amountMinor: 1000, dueOn: "2026-09-10"}),
      entry("p1", {kind: "payment", direction: "bToA", amountMinor: 1000}),
    ]), []);
  });

  it("borçlu a tarafıysa ve birimler ayrıysa doğru taraf", () => {
    const items = openDueItems([
      entry("e1", {direction: "bToA", amountMinor: 300, dueOn: "2026-09-12"}),
      entry("g1", {asset: "GAU", amountMinor: 2000, dueOn: "2026-09-11"}),
    ]);
    assert.deepEqual(
      items.map((i) => [i.entryId, i.asset, i.debtorSide]),
      [["g1", "GAU", "b"], ["e1", "TRY", "a"]]);
  });
});

describe("affectsDue", () => {
  it("yalnızca onaylı kümeyi değiştiren yazımlar", () => {
    assert.equal(affectsDue(undefined, {state: "pending"}), false);
    assert.equal(affectsDue({state: "pending"}, {state: "confirmed"}), true);
    assert.equal(affectsDue(undefined, {state: "confirmed"}), true);
    assert.equal(
      affectsDue({state: "confirmed"}, {state: "confirmed", reversedBy: "r"}),
      true);
    assert.equal(
      affectsDue({state: "confirmed"},
        {state: "confirmed", reversalPendingId: "r"}),
      false);
  });
});
