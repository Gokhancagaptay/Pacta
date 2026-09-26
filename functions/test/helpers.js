// Emulator testlerinin ortak parçaları. Dosyalar aynı veritabanını
// sıfırladığı için sırayla çalışır (package.json: --test-concurrency=1).
const {after, before, beforeEach} = require("node:test");
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");

const fft = require("firebase-functions-test")({projectId: "demo-pacta"});
const fns = require("../lib/index.js");
const {db} = require("../lib/common/firebase.js");

// Varsayılan: e-postası doğrulanmış oturum; verified=false doğrulanmamış.
const call = (fn, uid, data, {verified = true} = {}) =>
  fft.wrap(fn)({
    data,
    auth: uid ? {uid, token: {email_verified: verified}} : undefined,
  });

const rejectsWith = (promise, code, text) =>
  assert.rejects(promise, (e) => {
    assert.equal(e.code, code, e.message);
    if (text) assert.match(e.message, text);
    return true;
  });

const today = "2026-09-25";
// Günlük sayaçlar sunucunun gerçek tarihine (İstanbul) göre tutulur.
const limitDay = require("../lib/ledger/model.js").todayIstanbul();
const ledgerDoc = (id) => db.collection("ledgers").doc(id).get();
const entryDoc = (ledgerId, entryId) =>
  db.collection("ledgers").doc(ledgerId)
    .collection("entries").doc(entryId).get();
const inboxDoc = (uid, entryId) =>
  db.collection("users").doc(uid).collection("inbox").doc(entryId).get();
const notifications = (uid) =>
  db.collection("users").doc(uid).collection("notifications").get();

async function sharedLedger() {
  const res = await call(fns.createLedger, "ali", {counterpartyUid: "ayse"});
  return res.ledgerId;
}

async function lend(ledgerId, uid, amountMinor, extra = {}) {
  const entryId = randomUUID();
  const res = await call(fns.createEntry, uid, {
    ledgerId, entryId, kind: "debt", iGave: true, asset: "TRY",
    amountMinor, occurredOn: today, description: "Yemek", ...extra,
  });
  return {entryId, ...res};
}

/** Her testten önce veritabanını boşaltır, üç kullanıcı ekler. */
function useEmulator() {
  before(() => {
    assert.ok(process.env.FIRESTORE_EMULATOR_HOST, "Emulator gerekli");
  });

  beforeEach(async () => {
    const host = process.env.FIRESTORE_EMULATOR_HOST;
    await fetch(
      `http://${host}/emulator/v1/projects/demo-pacta/databases/(default)/documents`,
      {method: "DELETE"},
    );
    const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
    if (authHost) {
      await fetch(
        `http://${authHost}/emulator/v1/projects/demo-pacta/accounts`,
        {method: "DELETE"},
      );
      const auth = require("firebase-admin").auth();
      await Promise.all([
        auth.createUser(
          {uid: "ali", email: "ali@example.com", emailVerified: true}),
        auth.createUser(
          {uid: "ayse", email: "ayse@example.com", emailVerified: true}),
        auth.createUser(
          {uid: "mallory", email: "m@example.com", emailVerified: false}),
      ]);
    }
    await Promise.all([
      db.collection("users").doc("ali").set({adSoyad: "Ali Veli"}),
      db.collection("users").doc("ayse").set({adSoyad: "Ayşe Yılmaz"}),
      db.collection("users").doc("mallory").set({adSoyad: "Mallory"}),
    ]);
  });

  after(() => fft.cleanup());
}

module.exports = {
  call,
  db,
  entryDoc,
  fft,
  fns,
  inboxDoc,
  lend,
  ledgerDoc,
  limitDay,
  notifications,
  rejectsWith,
  sharedLedger,
  today,
  useEmulator,
};
