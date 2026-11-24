// Günlük bakım: 30 günde doğrulanmamış e-posta hesapları, saklama süresi
// (10 yıl) dolan kapalı ortak defterler ve 90 günden eski bildirimler
// silinir; diğer her şey kalır.
const {describe, it} = require("node:test");
const assert = require("node:assert/strict");

const {
  NOTIFICATION_DAYS,
  runMaintenance,
} = require("../lib/ledger/maintenance.js");
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
      {unverified: 0, closedLedgers: 0, tombstones: 0, web: 0,
        notifications: 0, resumed: 0, failed: 0});
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

describe("bildirim saklama süresi", () => {
  const {Timestamp} = require("firebase-admin/firestore");
  const ago = (days) => Timestamp.fromMillis(Date.now() - days * DAY);
  const note = (days) => ({
    type: "entryRecorded", title: "Kayıt", message: "Yeni kayıt",
    isRead: false, createdAt: ago(days),
  });

  it("90 günden eski bildirimleri siler, yenilere dokunmaz", async () => {
    assert.equal(NOTIFICATION_DAYS, 90);
    await Promise.all([
      db.doc("users/ali/notifications/eski").set(note(100)),
      db.doc("users/ali/notifications/yeni").set(note(5)),
      db.doc("users/ayse/notifications/eski").set(note(91)),
      db.doc("users/ayse/notifications/yeni").set(note(89)),
      db.doc("users/ayse/inbox/e1").set({type: "confirmEntry",
        createdAt: ago(100)}),
    ]);

    const res = await runMaintenance(new Date());
    assert.equal(res.notifications, 2);
    assert.equal(res.failed, 0);
    assert.equal(await exists("users/ali/notifications/eski"), false);
    assert.equal(await exists("users/ayse/notifications/eski"), false);
    assert.equal(await exists("users/ali/notifications/yeni"), true);
    assert.equal(await exists("users/ayse/notifications/yeni"), true);
    // Kişinin diğer verisi kalır.
    assert.equal(await exists("users/ali"), true);
    assert.equal(await exists("users/ayse/inbox/e1"), true);

    // Saat ileri alınınca kalanlar da süresini doldurur.
    const later80 = await runMaintenance(later(80 * DAY));
    assert.equal(later80.notifications, 1);
    assert.equal(await exists("users/ali/notifications/yeni"), true);
    assert.equal(await exists("users/ayse/notifications/yeni"), false);
  });

  it("v1 kök bildirimlerine ve başka yoldaki belgelere dokunmaz",
    async () => {
      // 450 eski kök belge: ilk sayfa tamamen atlanır, imleç ilerler.
      for (let start = 0; start < 450; start += 150) {
        const batch = db.batch();
        for (let i = start; i < start + 150; i++) {
          batch.set(db.doc(`notifications/v1_${i}`),
            {toUserId: "ali", message: "Eski", createdAt: ago(400)});
        }
        await batch.commit();
      }
      await Promise.all([
        db.doc("ledgers/x/notifications/n1").set(note(400)),
        db.doc("users/ali/notifications/eski").set(note(100)),
      ]);

      const res = await runMaintenance(new Date());
      assert.equal(res.notifications, 1);
      assert.equal(res.failed, 0);
      assert.equal(await exists("users/ali/notifications/eski"), false);
      assert.equal((await db.collection("notifications").get()).size, 450);
      assert.equal(await exists("ledgers/x/notifications/n1"), true);
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
