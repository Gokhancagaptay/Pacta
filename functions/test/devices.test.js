// Bildirim anahtarları cihaz başına ve tek sahipli.
const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {call, db, fns, rejectsWith, useEmulator} = require("./helpers.js");

useEmulator();

const tokensOf = async (uid) =>
  (await db.doc(`users/${uid}`).get()).get("fcmTokens");

describe("bildirim anahtarları", () => {
  it("anahtar yeni hesaba geçince eski hesaptan silinir", async () => {
    await call(fns.registerPushToken, "ali", {token: "telefon-1"});
    assert.deepEqual(await tokensOf("ali"), ["telefon-1"]);
    // Ali internetsiz çıkış yaptı; aynı telefonda Ayşe giriş yapıyor.
    await call(fns.registerPushToken, "ayse", {token: "telefon-1"});
    assert.deepEqual(await tokensOf("ali"), []);
    assert.deepEqual(await tokensOf("ayse"), ["telefon-1"]);
  });

  it("eski tek anahtar alanı taşınır ve başkasınınki temizlenir", async () => {
    await db.doc("users/ali").update({fcmToken: "tablet"});
    await db.doc("users/ayse").update({fcmToken: "ortak"});
    await call(fns.registerPushToken, "ali", {token: "ortak"});
    const ali = await db.doc("users/ali").get();
    assert.equal(ali.get("fcmToken"), undefined);
    assert.deepEqual(ali.get("fcmTokens"), ["ortak"]);
    assert.equal((await db.doc("users/ayse").get()).get("fcmToken"),
      undefined);
  });

  it("en fazla 5 cihaz; en eskisi düşer; çıkışta yalnızca bu cihaz silinir",
    async () => {
      for (let i = 1; i <= 6; i++) {
        await call(fns.registerPushToken, "ali", {token: `c${i}`});
      }
      assert.deepEqual(await tokensOf("ali"), ["c6", "c5", "c4", "c3", "c2"]);
      await call(fns.unregisterPushToken, "ali", {token: "c4"});
      assert.deepEqual(await tokensOf("ali"), ["c6", "c5", "c3", "c2"]);
    });

  it("web misafiri ve oturumsuz istek anahtar kaydedemez", async () => {
    await db.doc("webGuests/ayse").set({createdAt: new Date()});
    await rejectsWith(call(fns.registerPushToken, "ayse", {token: "x"}),
      "failed-precondition");
    await rejectsWith(call(fns.registerPushToken, null, {token: "x"}),
      "unauthenticated");
  });
});
