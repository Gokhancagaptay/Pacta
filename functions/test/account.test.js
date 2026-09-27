// Hesap silme: kişisel veriler silinir, ortak geçmiş karşı tarafta takma
// adla ("Silinmiş kullanıcı") kalır, açık kayıtlar kapanır; iki taraf da
// silerse defter tamamen silinir.
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
const exists = async (path) => (await db.doc(path).get()).exists;

const authGone = (uid) => assert.rejects(
  require("firebase-admin").auth().getUser(uid),
  (e) => e.code === "auth/user-not-found");

describe("deleteAccount", () => {
  it("eski oturumla hesap silinemez, hiçbir şey silinmez", async () => {
    await rejectsWith(
      call(fns.deleteAccount, "ali", {}, stale()),
      "failed-precondition", /REAUTH_REQUIRED/);
    await rejectsWith(call(fns.deleteAccount, null, {}), "unauthenticated");
    assert.equal(await exists("users/ali"), true);
    assert.equal(await exists("deletedAccounts/ali"), false);
    await require("firebase-admin").auth().getUser("ali");
  });

  it("kişisel veri silinir, ortak geçmiş karşı tarafta takma adla kalır",
    async () => {
      const ledgerId = await sharedLedger();
      const confirmed = await lend(ledgerId, "ali", 50000,
        {dueOn: "2026-12-01"});
      await call(fns.confirmEntry, "ayse",
        {ledgerId, entryId: confirmed.entryId, expectedVersion: 1});
      const alisPending = await lend(ledgerId, "ali", 1000);
      const aysesPayment = randomUUID();
      await call(fns.createEntry, "ayse", {
        ledgerId, entryId: aysesPayment, kind: "payment", iGave: true,
        asset: "TRY", amountMinor: 2000, occurredOn: today,
      });
      // Ayşe, Ali lehine onaylı kaydı düzeltmek istiyor (Ali'yi bekler).
      const reversalId = randomUUID();
      await call(fns.reverseEntry, "ayse",
        {ledgerId, entryId: confirmed.entryId, reversalId});
      const {ledgerId: privateId} = await call(fns.createLedger, "ali",
        {privateName: "Bakkal"});
      const {code} = await call(fns.myPactaCode, "ali", {});
      // Ali'nin gece gönderdiği, sabaha kalmış hatırlatma.
      await db.collection("pushQueue").add({
        uid: "ayse", title: "t", message: "Ali Veli ile…",
        data: {ledgerId}, sendAfter: new Date(),
      });

      const res = await call(fns.deleteAccount, "ali", {}, fresh());
      assert.deepEqual(res,
        {deleted: true, closedLedgers: 1, deletedLedgers: 1});

      // Kişisel veriler ve giriş hesabı silindi; silme işareti yazıldı.
      assert.equal(await exists(`ledgers/${privateId}`), false);
      assert.equal(await exists("users/ali"), false);
      assert.equal(await exists("publicProfiles/ali"), false);
      assert.equal(await exists(`codes/${code}`), false);
      assert.equal(await exists("rateLimits/ledgers_ali"), false);
      assert.equal(await exists("rateLimits/entries_ali"), false);
      assert.equal(await exists("deletedAccounts/ali"), true);
      await authGone("ali");
      const queued = await db.collection("pushQueue")
        .where("data.ledgerId", "==", ledgerId).get();
      assert.equal(queued.size, 0);

      // Ortak defter kapandı; Ali takma adlı, bakiye korunuyor, vadeler
      // temizlendi.
      const ledger = await ledgerDoc(ledgerId);
      assert.equal(ledger.get("status"), "closed");
      assert.equal(ledger.get("sides.a.displayName"), "Silinmiş kullanıcı");
      assert.equal(ledger.get("sides.a.email"), null);
      assert.equal(ledger.get("sides.a.deleted"), true);
      assert.equal(ledger.get("sides.b.displayName"), "Ayşe Yılmaz");
      assert.equal(ledger.get("balances.TRY"), 50000);
      assert.equal(ledger.get("pendingCount"), 0);
      assert.deepEqual(ledger.get("dueItems"), []);

      // Açık kayıtlar kapandı; bekleyen düzeltme bağı çözüldü.
      assert.equal(
        (await entryDoc(ledgerId, alisPending.entryId)).get("state"),
        "cancelled");
      const payment = await entryDoc(ledgerId, aysesPayment);
      assert.equal(payment.get("state"), "rejected");
      assert.equal(payment.get("rejection.reason"), "accountDeleted");
      assert.equal((await entryDoc(ledgerId, reversalId)).get("state"),
        "rejected");
      assert.equal(
        (await entryDoc(ledgerId, confirmed.entryId)).get("reversalPendingId"),
        null);
      assert.equal(
        (await inboxDoc("ayse", alisPending.entryId)).exists, false);
      const events = await db.collection(`ledgers/${ledgerId}/events`)
        .where("reason", "==", "accountDeleted").get();
      assert.equal(events.size, 3);

      // Ayşe tek bir bildirim aldı; deftere yeni kayıt ekleyemez.
      const notes = (await notifications("ayse")).docs
        .filter((d) => d.get("type") === "accountDeleted");
      assert.equal(notes.length, 1);
      assert.equal(notes[0].id, `accountDeleted_${ledgerId}`);
      await rejectsWith(lend(ledgerId, "ayse", 100), "failed-precondition",
        /kapalı/);

      // Tekrar çalıştırmak değişiklik yapmaz, bildirimi çoğaltmaz.
      assert.deepEqual(await deleteAccountData("ali"),
        {closedLedgers: 0, deletedLedgers: 0});
      assert.equal((await notifications("ayse")).docs
        .filter((d) => d.get("type") === "accountDeleted").length, 1);
    });

  it("silinen hesabın eski oturumu işlem yapamaz, kimse onunla defter açamaz",
    async () => {
      await call(fns.deleteAccount, "ali", {}, fresh());
      await rejectsWith(
        call(fns.createLedger, "ali", {privateName: "Yeni"}),
        "permission-denied", /silindi/);
      await rejectsWith(
        call(fns.myPactaCode, "ali", {}), "permission-denied");
      await rejectsWith(
        call(fns.createLedger, "ayse", {counterpartyUid: "ali"}),
        "not-found");
    });

  it("iki taraf da silerse ortak defter tamamen silinir", async () => {
    const ledgerId = await sharedLedger();
    const e = await lend(ledgerId, "ali", 500);
    await call(fns.confirmEntry, "ayse",
      {ledgerId, entryId: e.entryId, expectedVersion: 1});
    await call(fns.deleteAccount, "ali", {}, fresh());
    assert.equal((await ledgerDoc(ledgerId)).get("status"), "closed");

    const res = await call(fns.deleteAccount, "ayse", {}, fresh());
    assert.equal(res.deletedLedgers, 1);
    assert.equal((await ledgerDoc(ledgerId)).exists, false);
    const entries = await db.collection(`ledgers/${ledgerId}/entries`).get();
    assert.equal(entries.size, 0);
    // Önce silinen Ali'ye sahipsiz bildirim yazılmadı.
    assert.equal((await notifications("ali")).size, 0);
  });

  it("doğrulanmamış hesap da kendini silebilir", async () => {
    const res = await call(fns.deleteAccount, "mallory", {},
      {verified: false, ...fresh()});
    assert.equal(res.deleted, true);
    await authGone("mallory");
  });
});
