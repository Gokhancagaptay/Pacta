// Günlük bakım: 30 günde doğrulanmamış e-posta hesapları ve saklama süresi
// (10 yıl) dolan kapalı ortak defterler silinir; diğer her şey kalır.
const {describe, it} = require("node:test");
const assert = require("node:assert/strict");

const {runMaintenance} = require("../lib/ledger/maintenance.js");
const {
  call,
  db,
  fns,
  lend,
  ledgerDoc,
  sharedLedger,
  useEmulator,
} = require("./helpers.js");

useEmulator();

const DAY = 24 * 60 * 60 * 1000;
const later = (ms) => new Date(Date.now() + ms);
const exists = async (path) => (await db.doc(path).get()).exists;

describe("runMaintenance", () => {
  it("30 günü geçen doğrulanmamış şifreli hesabı siler", async () => {
    const auth = require("firebase-admin").auth();
    await auth.createUser({
      uid: "eski", email: "eski@example.com", password: "gizli-123456",
      emailVerified: false,
    });
    await db.collection("users").doc("eski").set({adSoyad: "Eski"});

    assert.deepEqual(await runMaintenance(later(DAY)),
      {unverified: 0, closedLedgers: 0, tombstones: 0, web: 0, resumed: 0,
        failed: 0});
    await auth.getUser("eski");

    const res = await runMaintenance(later(31 * DAY));
    assert.equal(res.unverified, 1);
    await assert.rejects(auth.getUser("eski"),
      (e) => e.code === "auth/user-not-found");
    assert.equal(await exists("users/eski"), false);
    assert.equal(await exists("deletedAccounts/eski"), true);
    // Doğrulanmış hesaplar ve şifresiz hesaplar dokunulmadan kalır.
    await auth.getUser("ali");
    await auth.getUser("mallory");
    assert.equal(await exists("users/ali"), true);
  });

  it("kapalı ortak defteri ve silme işaretini 10 yıl sonra siler",
    async () => {
      const ledgerId = await sharedLedger();
      const e = await lend(ledgerId, "ali", 500);
      await call(fns.confirmEntry, "ayse",
        {ledgerId, entryId: e.entryId, expectedVersion: 1});
      await call(fns.deleteAccount, "ali", {},
        {authTime: Math.floor(Date.now() / 1000) - 30});
      assert.equal((await ledgerDoc(ledgerId)).get("status"), "closed");

      const nineYears = await runMaintenance(later(9 * 365 * DAY));
      assert.equal(nineYears.closedLedgers, 0);
      assert.equal(nineYears.tombstones, 0);
      assert.equal((await ledgerDoc(ledgerId)).exists, true);

      const res = await runMaintenance(later(3654 * DAY));
      assert.equal(res.closedLedgers, 1);
      assert.equal(res.tombstones, 1);
      assert.equal((await ledgerDoc(ledgerId)).exists, false);
      const entries = await db.collection(`ledgers/${ledgerId}/entries`).get();
      assert.equal(entries.size, 0);
      assert.equal(await exists("deletedAccounts/ali"), false);
    });

  it("açık defterlere dokunmaz", async () => {
    const ledgerId = await sharedLedger();
    await lend(ledgerId, "ali", 500);
    const res = await runMaintenance(later(3654 * DAY));
    assert.equal(res.closedLedgers, 0);
    assert.equal((await ledgerDoc(ledgerId)).exists, true);
  });
});

describe("yarım kalan hesap silme", () => {
  it("bakım bir saatten eski yarım silmeyi tamamlar", async () => {
    const ledgerId = (await call(fns.createLedger, "ali",
      {privateName: "Bakkal"})).ledgerId;
    // Silme başlamış, işaret yazılmış ama işlem yarıda kalmış.
    await db.doc("deletedAccounts/ali").set({
      deletedAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
      reason: "user",
      pending: true,
    });
    const res = await runMaintenance(new Date());
    assert.equal(res.resumed, 1);
    assert.equal(await exists("users/ali"), false);
    assert.equal((await ledgerDoc(ledgerId)).exists, false);
    const marker = await db.doc("deletedAccounts/ali").get();
    assert.equal(marker.get("pending"), false);
    await assert.rejects(require("firebase-admin").auth().getUser("ali"),
      (e) => e.code === "auth/user-not-found");
  });
});
