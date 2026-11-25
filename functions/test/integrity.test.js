// Denetim düzeltmeleri: kayıt ezme, sınırlar, tekrar denenen komutlar,
// üye olmayana aynı yanıt, engelleme.
const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");

const {transferLines} = require("../lib/ledger/commands.js");
const {recomputeDue} = require("../lib/ledger/due.js");
const {
  call,
  db,
  entryDoc,
  fns,
  lend,
  ledgerDoc,
  limitDay,
  rejectsWith,
  sharedLedger,
  today,
  useEmulator,
} = require("./helpers.js");

useEmulator();

async function privateWithLoan(amountMinor = 100000) {
  const {ledgerId} = await call(fns.createLedger, "ali",
    {privateName: "Ayşe (defterim)"});
  await lend(ledgerId, "ali", amountMinor);
  return ledgerId;
}

describe("kayıt ezme", () => {
  it("istemci taşıma kimliği kullanamaz; önceden yazılmış kayıt ezilmez",
    async () => {
      const privateId = await privateWithLoan();
      const sharedId = await sharedLedger();
      await rejectsWith(call(fns.createEntry, "ali", {
        ledgerId: sharedId, entryId: `t_${privateId}_0`, kind: "debt",
        iGave: false, asset: "TRY", amountMinor: 1000, occurredOn: today,
      }), "invalid-argument");

      const target = db.doc(`ledgers/${sharedId}/entries/t_${privateId}_0`);
      await target.set({marker: "eski"});
      await rejectsWith(call(fns.convertPrivateLedger, "ali",
        {ledgerId: privateId, counterpartyUid: "ayse"}), "already-exists");
      assert.deepEqual((await target.get()).data(), {marker: "eski"});
      assert.equal((await ledgerDoc(privateId)).get("status"), "active");
    });

  it("taşıma bekleyen kayıt sınırına takılmaz", async () => {
    const privateId = await privateWithLoan();
    const sharedId = await sharedLedger();
    await db.doc(`ledgers/${sharedId}`).update({pendingCount: 50});
    const res = await call(fns.convertPrivateLedger, "ali",
      {ledgerId: privateId, counterpartyUid: "ayse"});
    assert.equal(res.pending, 1);
  });

  it("çok büyük kalan bakiye tutar sınırına göre parçalanır", () => {
    const lines = transferLines([{
      id: "d", kind: "debt", direction: "aToB", asset: "TRY",
      amountMinor: 25e12, deltaMinor: 25e12, occurredOn: "2026-01-01",
      dueOn: null, description: "", linkedEntryId: null, reversedBy: null,
      confirmedSeq: 1,
    }], "2026-09-27", false);
    assert.deepEqual(lines.map((l) => l.amountMinor), [1e13, 1e13, 5e12]);
  });
});

describe("sınırlar ve tekrar denemeler", () => {
  it("günlük düzeltme (ters kayıt) sınırı", async () => {
    const ledgerId = await sharedLedger();
    const {entryId} = await lend(ledgerId, "ali", 100, {iGave: false});
    await db.doc("rateLimits/reversals_ali").set({day: limitDay, count: 50});
    await rejectsWith(call(fns.reverseEntry, "ali",
      {ledgerId, entryId, reversalId: randomUUID()}), "resource-exhausted");
  });

  it("itiraz, ret ve geri çekme tekrar gönderilince aynı sonucu döner",
    async () => {
      const ledgerId = await sharedLedger();
      const a = await lend(ledgerId, "ali", 1000);
      const b = await lend(ledgerId, "ali", 2000);
      const c = await lend(ledgerId, "ali", 3000);
      const key = (e) => ({ledgerId, entryId: e.entryId, expectedVersion: 1});

      const dispute = {...key(a), reason: "amount"};
      const first = await call(fns.disputeEntry, "ayse", dispute);
      assert.deepEqual(await call(fns.disputeEntry, "ayse", dispute), first);

      const reject = {...key(b), reason: "notAgreed"};
      const rejected = await call(fns.rejectEntry, "ayse", reject);
      assert.deepEqual(await call(fns.rejectEntry, "ayse", reject), rejected);

      const cancelled = await call(fns.cancelEntry, "ali", key(c));
      assert.deepEqual(await call(fns.cancelEntry, "ali", key(c)), cancelled);
      assert.equal((await ledgerDoc(ledgerId)).get("pendingCount"), 1);
    });

  it("hiçbir şeyi değiştirmeyen düzeltme reddedilir", async () => {
    const ledgerId = await sharedLedger();
    const e = await lend(ledgerId, "ali", 1000);
    await rejectsWith(call(fns.reviseEntry, "ali", {
      ledgerId, entryId: e.entryId, expectedVersion: 1, amountMinor: 1000,
    }), "invalid-argument", /değiştirmediniz/);
  });
});

describe("gizlilik ve temizlik", () => {
  it("üye olmayan kişi defterin varlığını öğrenemez", async () => {
    const ledgerId = await sharedLedger();
    await rejectsWith(call(fns.setBlocked, "mallory",
      {ledgerId, blocked: true}), "not-found");
    await rejectsWith(call(fns.setBlocked, "mallory",
      {ledgerId: "p_ali_yokkisi", blocked: true}), "not-found");
  });

  it("silinmiş özel defterin web istekleri tekrar denemede de silinir",
    async () => {
      const gone = "v_gitti0";
      await db.doc("webRequests/r1").set({ownerUid: "ali", ledgerId: gone});
      await db.doc("webRequests/r2").set({ownerUid: "veli", ledgerId: gone});
      assert.deepEqual(await call(fns.deletePrivateLedger, "ali",
        {ledgerId: "v_gitti0"}), {deleted: false});
      assert.equal((await db.doc("webRequests/r1").get()).exists, false);
      assert.equal((await db.doc("webRequests/r2").get()).exists, true);
    });

  it("kapalı defterde vade listesi geri yazılmaz, boşaltılır", async () => {
    await db.doc("ledgers/p_kapali01").set({
      status: "closed",
      dueItems: [{entryId: "x", dueOn: "2026-10-01"}],
      dueDates: ["2026-10-01"],
    });
    await recomputeDue("p_kapali01");
    const ledger = await ledgerDoc("p_kapali01");
    assert.deepEqual(ledger.get("dueItems"), []);
    assert.deepEqual(ledger.get("dueDates"), []);
  });
});

describe("engelleme", () => {
  it("engellenen kişi kayıt, düzeltme ve hatırlatma gönderemez", async () => {
    const ledgerId = await sharedLedger();
    const before = await lend(ledgerId, "ali", 1000);
    await call(fns.setBlocked, "ayse", {ledgerId, blocked: true});
    assert.equal((await ledgerDoc(ledgerId)).get("blockedBy.b"), true);

    await rejectsWith(lend(ledgerId, "ali", 500), "failed-precondition",
      /gönderilemiyor/);
    await rejectsWith(call(fns.reviseEntry, "ali", {
      ledgerId, entryId: before.entryId, expectedVersion: 1, amountMinor: 900,
    }), "failed-precondition", /gönderilemiyor/);
    await rejectsWith(call(fns.sendReminder, "ali", {ledgerId}),
      "failed-precondition", /gönderilemiyor/);
    // Kendi bekleyen kaydını geri çekebilir; engelleyen kayıt ekleyebilir.
    await call(fns.cancelEntry, "ali",
      {ledgerId, entryId: before.entryId, expectedVersion: 1});
    await lend(ledgerId, "ayse", 700);

    await call(fns.setBlocked, "ayse", {ledgerId, blocked: false});
    assert.equal((await ledgerDoc(ledgerId)).get("blockedBy.b"), undefined);
    const after = await lend(ledgerId, "ali", 500);
    assert.equal((await entryDoc(ledgerId, after.entryId)).get("state"),
      "pending");
  });

  it("özel defterde engelleme yok", async () => {
    const privateId = await privateWithLoan();
    await rejectsWith(call(fns.setBlocked, "ali",
      {ledgerId: privateId, blocked: true}), "failed-precondition");
  });
});

describe("bağlı ödeme ve ters kayıt kimliği", () => {
  const pay = (ledgerId, uid, linkedEntryId, extra = {}) =>
    call(fns.createEntry, uid, {
      ledgerId, entryId: randomUUID(), kind: "payment", iGave: false,
      asset: "TRY", amountMinor: 100, occurredOn: today, linkedEntryId,
      ...extra,
    });

  it("ödeme yalnızca onaylı, aynı birimli borcu kapatan yönde bağlanır",
    async () => {
      const ledgerId = await sharedLedger();
      const pending = await lend(ledgerId, "ali", 1000);
      await rejectsWith(pay(ledgerId, "ali", pending.entryId),
        "failed-precondition", /onaylı/);
      await call(fns.confirmEntry, "ayse",
        {ledgerId, entryId: pending.entryId, expectedVersion: 1});
      await rejectsWith(pay(ledgerId, "ali", pending.entryId, {asset: "USD"}),
        "invalid-argument", /aynı birimde/);
      // Borç veren ödeme "yaptım" diyemez: bu borcu kapatmaz.
      await rejectsWith(pay(ledgerId, "ali", pending.entryId, {iGave: true}),
        "invalid-argument", /kapatmaz/);
      const ok = await pay(ledgerId, "ali", pending.entryId);
      assert.equal(ok.state, "confirmed");
    });

  it("düzeltme kimliği düzeltilen kaydın kendisi olamaz", async () => {
    const ledgerId = await sharedLedger();
    const {entryId} = await lend(ledgerId, "ali", 100, {iGave: false});
    await rejectsWith(call(fns.reverseEntry, "ali",
      {ledgerId, entryId, reversalId: entryId}), "invalid-argument");
    const other = await lend(ledgerId, "ali", 200, {iGave: false});
    await rejectsWith(call(fns.reverseEntry, "ali",
      {ledgerId, entryId, reversalId: other.entryId}), "already-exists");
  });

  it("e-postayla kişi önizlemesi ad döner, sorgu sınırından düşer",
    async () => {
      const res = await call(fns.previewCode, "ali",
        {email: "AYSE@example.com"});
      assert.deepEqual(res, {self: false, displayName: "Ayşe Yılmaz"});
      assert.equal((await call(fns.previewCode, "ali",
        {email: "ali@example.com"})).self, true);
      await rejectsWith(call(fns.previewCode, "ali",
        {email: "m@example.com"}), "failed-precondition");
      const counter = await db.doc("rateLimits/codes_ali").get();
      assert.equal(counter.get("count"), 3);
    });
});
