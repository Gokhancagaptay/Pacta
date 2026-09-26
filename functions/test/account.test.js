// Hesap silme: kişisel veriler silinir, ortak geçmiş karşı tarafta anonim
// kalır, açık kayıtlar kapanır.
const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");

const {deleteAccountData} = require("../lib/ledger/account.js");
const {
  call,
  db,
  entryDoc,
  fns,
  inboxDoc,
  lend,
  ledgerDoc,
  notifications,
  rejectsWith,
  sharedLedger,
  today,
  useEmulator,
} = require("./helpers.js");

useEmulator();

const fresh = () => ({authTime: Math.floor(Date.now() / 1000) - 30});
const stale = () => ({authTime: Math.floor(Date.now() / 1000) - 3600});

describe("deleteAccount", () => {
  it("eski oturumla hesap silinemez", async () => {
    await rejectsWith(
      call(fns.deleteAccount, "ali", {}, stale()),
      "failed-precondition", /REAUTH_REQUIRED/);
    await rejectsWith(call(fns.deleteAccount, null, {}), "unauthenticated");
  });

  it("kişisel veri silinir, ortak geçmiş karşı tarafta anonim kalır",
    async () => {
      const ledgerId = await sharedLedger();
      const confirmed = await lend(ledgerId, "ali", 50000);
      await call(fns.confirmEntry, "ayse",
        {ledgerId, entryId: confirmed.entryId, expectedVersion: 1});
      const alisPending = await lend(ledgerId, "ali", 1000);
      const aysesPayment = randomUUID();
      await call(fns.createEntry, "ayse", {
        ledgerId, entryId: aysesPayment, kind: "payment", iGave: true,
        asset: "TRY", amountMinor: 2000, occurredOn: today,
      });
      const {ledgerId: privateId} = await call(fns.createLedger, "ali",
        {privateName: "Bakkal"});
      const {code} = await call(fns.myPactaCode, "ali", {});

      const res = await call(fns.deleteAccount, "ali", {}, fresh());
      assert.deepEqual(res,
        {deleted: true, closedLedgers: 1, deletedLedgers: 1});

      // Özel defter, profil, kod ve giriş hesabı silindi.
      assert.equal((await ledgerDoc(privateId)).exists, false);
      assert.equal((await db.collection("users").doc("ali").get()).exists,
        false);
      assert.equal((await db.collection("codes").doc(code).get()).exists,
        false);
      await assert.rejects(require("firebase-admin").auth().getUser("ali"));

      // Ortak defter kapandı, ali anonim; onaylı bakiye korunuyor.
      const ledger = await ledgerDoc(ledgerId);
      assert.equal(ledger.get("status"), "closed");
      assert.equal(ledger.get("sides.a.displayName"), "Silinmiş kullanıcı");
      assert.equal(ledger.get("sides.a.email"), null);
      assert.equal(ledger.get("sides.a.deleted"), true);
      assert.equal(ledger.get("sides.b.displayName"), "Ayşe Yılmaz");
      assert.equal(ledger.get("balances.TRY"), 50000);
      assert.equal(ledger.get("pendingCount"), 0);

      // Açık kayıtlar kapandı; Ayşe'nin gelen kutusu temizlendi.
      assert.equal(
        (await entryDoc(ledgerId, alisPending.entryId)).get("state"),
        "cancelled");
      const payment = await entryDoc(ledgerId, aysesPayment);
      assert.equal(payment.get("state"), "rejected");
      assert.equal(payment.get("rejection.reason"), "accountDeleted");
      assert.equal(
        (await inboxDoc("ayse", alisPending.entryId)).exists, false);

      // Ayşe bilgilendirildi ve bu deftere yeni kayıt ekleyemez.
      const notes = await notifications("ayse");
      assert.ok(notes.docs.some((d) => d.get("type") === "accountDeleted"));
      await rejectsWith(lend(ledgerId, "ayse", 100), "failed-precondition",
        /kapalı/);

      // Yarıda kalan silme tekrar çalıştırılabilir; değişiklik yapmaz.
      assert.deepEqual(await deleteAccountData("ali"),
        {closedLedgers: 0, deletedLedgers: 0});
    });

  it("doğrulanmamış hesap da kendini silebilir", async () => {
    const res = await call(fns.deleteAccount, "mallory", {},
      {verified: false, ...fresh()});
    assert.equal(res.deleted, true);
  });
});
