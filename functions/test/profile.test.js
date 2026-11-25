// Ad değişikliği defterlere yansır.
const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {call, db, fns, ledgerDoc, useEmulator} = require("./helpers.js");
const {cleanName, propagateName} = require("../lib/ledger/profile.js");

useEmulator();

describe("ad değişikliği", () => {
  it("kişinin tüm defterlerinde görünen adı güncellenir", async () => {
    const {ledgerId: shared} = await call(fns.createLedger, "ali",
      {counterpartyUid: "ayse"});
    const {ledgerId: priv} = await call(fns.createLedger, "ali",
      {privateName: "Bakkal"});
    assert.equal(await propagateName("ali", "Ali Yeni"), 2);
    assert.equal((await ledgerDoc(shared)).get("sides.a.displayName"),
      "Ali Yeni");
    assert.equal((await ledgerDoc(priv)).get("sides.a.displayName"),
      "Ali Yeni");
    // Özel defterdeki karşı tarafın adı (sahibin etiketi) değişmez.
    assert.equal((await ledgerDoc(priv)).get("sides.b.displayName"), "Bakkal");
    assert.equal(await propagateName("ali", "Ali Yeni"), 0);
  });

  it("hesabını silmiş tarafın adına dokunulmaz", async () => {
    const {ledgerId} = await call(fns.createLedger, "ali",
      {counterpartyUid: "ayse"});
    await db.doc(`ledgers/${ledgerId}`).update({
      "sides.a.deleted": true,
      "sides.a.displayName": "Silinmiş kullanıcı",
    });
    assert.equal(await propagateName("ali", "Ali Yeni"), 0);
  });

  it("ad tek satıra indirilir ve kısaltılır", () => {
    assert.equal(cleanName("  Ali \n  Veli "), "Ali Veli");
    assert.equal(cleanName("x".repeat(100)).length, 80);
    assert.equal(cleanName("   "), null);
    assert.equal(cleanName(undefined), null);
  });
});
