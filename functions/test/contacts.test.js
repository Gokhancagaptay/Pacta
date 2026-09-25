// Kişi ekleme (e-posta, Pacta kodu), kod üretimi, özel defter silme.
const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");

const {normalizeCode} = require("../lib/ledger/contacts.js");
const {
  call,
  db,
  fns,
  ledgerDoc,
  rejectsWith,
  today,
  useEmulator,
} = require("./helpers.js");

useEmulator();

const CODE = /^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/;

describe("normalizeCode", () => {
  it("tire, küçük harf ve davet linki kabul edilir", () => {
    assert.equal(normalizeCode("k7q-3xm"), "K7Q3XM");
    assert.equal(
      normalizeCode("https://pacta-76686.web.app/u/K7Q3XM"), "K7Q3XM");
    assert.equal(normalizeCode("K7Q3X"), null);
    assert.equal(normalizeCode("K7Q3X0"), null); // 0 alfabede yok
  });
});

describe("e-postayla ekleme", () => {
  it("defter açılır, iki tarafın e-postası görünür", async () => {
    const res = await call(fns.createLedger, "ali",
      {counterpartyEmail: " AYSE@example.com "});
    assert.equal(res.ledgerId, "p_ali_ayse");
    assert.equal(res.created, true);
    assert.equal(res.displayName, "Ayşe Yılmaz");
    const ledger = await ledgerDoc(res.ledgerId);
    assert.equal(ledger.get("sides.a.email"), "ali@example.com");
    assert.equal(ledger.get("sides.b.email"), "ayse@example.com");
  });

  it("neden eklenemediği açıkça söylenir", async () => {
    await rejectsWith(
      call(fns.createLedger, "ali", {counterpartyEmail: "yok@example.com"}),
      "not-found", /kayıtlı bir Pacta kullanıcısı yok/);
    await rejectsWith(
      call(fns.createLedger, "ali", {counterpartyEmail: "m@example.com"}),
      "failed-precondition", /doğrulamamış/);
    await rejectsWith(
      call(fns.createLedger, "ali", {counterpartyEmail: "ali@example.com"}),
      "invalid-argument", /sizin hesabınız/);
  });

  it("eski defterde eksik e-postalar tamamlanır", async () => {
    await db.collection("ledgers").doc("p_ali_ayse").set({
      mode: "shared", status: "active", memberUids: ["ali", "ayse"],
      sides: {
        a: {uid: "ayse", displayName: "Ayşe Yılmaz"},
        b: {uid: "ali", displayName: "Ali Veli"},
      },
      balances: {}, pendingCount: 0, head: {seq: 0, chainHash: ""},
    });
    const res = await call(fns.createLedger, "ali",
      {counterpartyEmail: "ayse@example.com"});
    assert.equal(res.created, false);
    const ledger = await ledgerDoc("p_ali_ayse");
    assert.equal(ledger.get("sides.a.email"), "ayse@example.com");
    assert.equal(ledger.get("sides.b.email"), "ali@example.com");
  });
});

describe("Pacta kodu", () => {
  it("kod bir kez üretilir, adı gösterir, defter açar", async () => {
    const {code} = await call(fns.myPactaCode, "ayse", {});
    assert.match(code, CODE);
    assert.equal((await call(fns.myPactaCode, "ayse", {})).code, code);
    assert.equal((await db.collection("codes").doc(code).get()).get("uid"),
      "ayse");

    const typed = `${code.slice(0, 3).toLowerCase()}-${code.slice(3)}`;
    const preview = await call(fns.previewCode, "ali", {code: typed});
    assert.deepEqual(preview, {self: false, displayName: "Ayşe Yılmaz"});
    assert.equal(
      (await call(fns.previewCode, "ayse", {code})).self, true);

    const res = await call(fns.createLedger, "ali",
      {counterpartyCode: `https://pacta-76686.web.app/u/${code}`});
    assert.equal(res.ledgerId, "p_ali_ayse");
  });

  it("yanlış kod ve günlük deneme sınırı", async () => {
    await rejectsWith(
      call(fns.previewCode, "ali", {code: "ZZZZZZ"}),
      "not-found", /bulunamadı/);
    await rejectsWith(
      call(fns.previewCode, "ali", {code: "abc"}),
      "invalid-argument", /6 karakter/);
    await db.collection("rateLimits").doc("codes_ali")
      .set({day: today, count: 30});
    await rejectsWith(
      call(fns.createLedger, "ali", {counterpartyCode: "ZZZZZZ"}),
      "resource-exhausted");
  });
});

describe("deletePrivateLedger", () => {
  it("özel defter kayıtlarıyla silinir; ortak defter silinmez", async () => {
    const {ledgerId} = await call(fns.createLedger, "ali",
      {privateName: "Bakkal Hasan"});
    await call(fns.createEntry, "ali", {
      ledgerId, entryId: randomUUID(), kind: "debt", iGave: false,
      asset: "TRY", amountMinor: 5000, occurredOn: today,
    });
    await rejectsWith(
      call(fns.deletePrivateLedger, "ayse", {ledgerId}), "permission-denied");
    assert.deepEqual(
      await call(fns.deletePrivateLedger, "ali", {ledgerId}), {deleted: true});
    assert.equal((await ledgerDoc(ledgerId)).exists, false);
    const entries = await db.collection("ledgers").doc(ledgerId)
      .collection("entries").get();
    assert.equal(entries.size, 0);

    const shared = await call(fns.createLedger, "ali",
      {counterpartyUid: "ayse"});
    await rejectsWith(
      call(fns.deletePrivateLedger, "ali", {ledgerId: shared.ledgerId}),
      "failed-precondition", /Listenizden/);
  });
});
