// Web onayı: uygulaması olmayan karşı taraf özel defterdeki kaydı
// e-postasını doğrulayarak onaylar, itiraz eder ya da reddeder.
const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {
  call,
  db,
  entryDoc,
  fft,
  fns,
  lend,
  ledgerDoc,
  notifications,
  rejectsWith,
  useEmulator,
} = require("./helpers");
const {
  webClock,
  purgeWebData,
  removeGuest,
} = require("../lib/ledger/web.js");
const {runMaintenance} = require("../lib/ledger/maintenance.js");

useEmulator();

const DAY = 24 * 60 * 60 * 1000;

/** E-posta bağlantısıyla girmiş web oturumu (uid yoksa oturumsuz). */
const web = (fn, data, {uid, email, verified = true} = {}) =>
  fft.wrap(fn)({
    data,
    auth: uid ? {uid, token: {email, email_verified: verified}} : undefined,
    rawRequest: {
      ip: "198.51.100.7",
      headers: {"user-agent": "Test/1.0", "x-forwarded-for": "203.0.113.5"},
    },
  });

const guest = {uid: "misafir", email: "Ahmet@Example.com"};

async function privateEntry(extra = {}) {
  const {ledgerId} = await call(fns.createLedger, "ali",
    {privateName: "Ahmet"});
  const {entryId} = await lend(ledgerId, "ali", 50000,
    {description: "Kira payı", ...extra});
  return {ledgerId, entryId};
}

async function request(ledgerId, entryId, extra = {}) {
  const res = await call(fns.requestWebConfirmation, "ali",
    {ledgerId, entryId, ...extra});
  const token = res.url.split("/o/")[1];
  return {...res, token};
}

async function createGuest() {
  await require("firebase-admin").auth().createUser({
    uid: guest.uid, email: guest.email.toLowerCase(), emailVerified: true,
  });
}

describe("requestWebConfirmation", () => {
  it("özel defterdeki kayda link üretir; token saklanmaz", async () => {
    const {ledgerId, entryId} = await privateEntry();
    const res = await request(ledgerId, entryId);
    assert.match(res.url, /^https:\/\/pacta-76686\.web\.app\/o\/[\w-]{32}$/);
    assert.match(res.expiresOn, /^\d{4}-\d{2}-\d{2}$/);
    const requests = await db.collection("webRequests").get();
    assert.equal(requests.size, 1);
    assert.notEqual(requests.docs[0].id, res.token);
    assert.equal(JSON.stringify(requests.docs[0].data()).includes(res.token),
      false);
    const entry = await entryDoc(ledgerId, entryId);
    assert.equal(entry.get("webConfirmation.state"), "requested");
    // Özel defterin bakiyesi değişmez.
    assert.equal((await ledgerDoc(ledgerId)).get("balances.TRY"), 50000);
  });

  it("ortak defterde ve başkasının defterinde çalışmaz", async () => {
    const {ledgerId: shared} = await call(fns.createLedger, "ali",
      {counterpartyUid: "ayse"});
    const {entryId: sharedEntry} = await lend(shared, "ali", 100);
    await rejectsWith(call(fns.requestWebConfirmation, "ali",
      {ledgerId: shared, entryId: sharedEntry}), "failed-precondition");
    const {ledgerId, entryId} = await privateEntry();
    await rejectsWith(call(fns.requestWebConfirmation, "ayse",
      {ledgerId, entryId}), "not-found");
  });

  it("yeni link eskisini geçersiz kılar; açıklama istenmezse gitmez",
    async () => {
      const {ledgerId, entryId} = await privateEntry();
      const first = await request(ledgerId, entryId);
      const second = await request(ledgerId, entryId,
        {includeDescription: false});
      assert.deepEqual(await web(fns.openWebConfirmation,
        {token: first.token}), {status: "revoked", ownerName: "Ali Veli"});
      await createGuest();
      const view = await web(fns.openWebConfirmation,
        {token: second.token}, guest);
      assert.equal(view.status, "open");
      assert.equal(view.description, "");
    });
});

describe("openWebConfirmation", () => {
  it("oturumsuz yalnızca durumu ve gönderenin adını gösterir", async () => {
    const {ledgerId, entryId} = await privateEntry();
    const {token} = await request(ledgerId, entryId);
    assert.deepEqual(await web(fns.openWebConfirmation, {token}),
      {status: "open", ownerName: "Ali Veli"});
    assert.deepEqual(
      await web(fns.openWebConfirmation, {token: "x".repeat(32)}),
      {status: "invalid"});
  });

  it("doğrulanmış e-postaya ayrıntıyı gösterir ve isteği ona bağlar",
    async () => {
      const {ledgerId, entryId} = await privateEntry({dueOn: "2026-10-30"});
      const {token} = await request(ledgerId, entryId);
      await createGuest();
      const view = await web(fns.openWebConfirmation, {token}, guest);
      assert.equal(view.status, "open");
      assert.equal(view.sentence,
        "Ali Veli, size 500,00 ₺ borç verdiğini kaydetti.");
      assert.equal(view.description, "Kira payı");
      assert.equal(view.dueOn, "2026-10-30");
      assert.equal(view.email, "ahmet@example.com");
      assert.equal((await db.doc("webGuests/misafir").get()).exists, true);

      const other = await web(fns.openWebConfirmation, {token},
        {uid: "baska", email: "b@example.com"});
      assert.equal(other.status, "otherEmail");
      assert.equal(other.sentence, undefined);
    });

  it("doğrulanmamış e-posta oturumsuz sayılır", async () => {
    const {ledgerId, entryId} = await privateEntry();
    const {token} = await request(ledgerId, entryId);
    const view = await web(fns.openWebConfirmation, {token},
      {...guest, verified: false});
    assert.deepEqual(view, {status: "open", ownerName: "Ali Veli"});
  });

  it("süresi dolan ya da düzeltilen kaydın linki kapanır", async (t) => {
    const {ledgerId, entryId} = await privateEntry();
    const {token} = await request(ledgerId, entryId);
    t.mock.method(webClock, "now", () => new Date(Date.now() + 15 * DAY));
    assert.equal((await web(fns.openWebConfirmation, {token})).status,
      "expired");
    t.mock.restoreAll();

    await call(fns.reverseEntry, "ali",
      {ledgerId, entryId, reversalId: "reversal-0001"});
    assert.equal((await web(fns.openWebConfirmation, {token})).status,
      "withdrawn");
  });

  it("linki oluşturan kendi isteğini açamaz", async () => {
    const {ledgerId, entryId} = await privateEntry();
    const {token} = await request(ledgerId, entryId);
    await rejectsWith(web(fns.openWebConfirmation, {token},
      {uid: "ali", email: "ali@example.com"}), "failed-precondition");
  });
});

describe("respondWebConfirmation", () => {
  it("onay kayda ve olaylara işlenir, sahibe bildirim gider, misafir silinir",
    async () => {
      const {ledgerId, entryId} = await privateEntry();
      const {token} = await request(ledgerId, entryId);
      await createGuest();
      await web(fns.openWebConfirmation, {token}, guest);
      const res = await web(fns.respondWebConfirmation,
        {token, action: "confirm"}, guest);
      assert.deepEqual(res, {status: "answered", answer: "confirm"});

      const entry = await entryDoc(ledgerId, entryId);
      assert.equal(entry.get("webConfirmation.state"), "confirmed");
      assert.equal(entry.get("webConfirmation.emailMasked"),
        "a***@example.com");
      assert.equal(entry.get("state"), "confirmed");
      const events = await db.collection(`ledgers/${ledgerId}/events`)
        .where("type", "==", "webConfirmed").get();
      assert.equal(events.size, 1);
      assert.deepEqual(events.docs[0].get("memberUids"), ["ali"]);

      const req = (await db.collection("webRequests").get()).docs[0];
      assert.equal(req.get("response.email"), "ahmet@example.com");
      // Sunucunun gördüğü adres; istemcinin yazabildiği zincir ayrı durur.
      assert.equal(req.get("response.ip"), "198.51.100.7");
      assert.equal(req.get("response.forwardedFor"), "203.0.113.5");
      assert.equal(req.get("response.userAgent"), "Test/1.0");
      assert.equal(req.get("purgeAfter"), undefined);

      const notes = await notifications("ali");
      assert.equal(notes.size, 1);
      assert.match(notes.docs[0].get("message"), /Ahmet kaydı web'de onayladı/);

      await assert.rejects(require("firebase-admin").auth().getUser("misafir"),
        (e) => e.code === "auth/user-not-found");
      assert.equal((await db.doc("webGuests/misafir").get()).exists, false);

      // Aynı yanıtın tekrarı aynı sonucu döner; başka yanıt reddedilir.
      assert.deepEqual(await web(fns.respondWebConfirmation,
        {token, action: "confirm"}, guest), res);
      await rejectsWith(web(fns.respondWebConfirmation,
        {token, action: "reject", reason: "notAgreed"}, guest),
      "failed-precondition");
      // Onaylanan kayda yeni link istenmez.
      await rejectsWith(call(fns.requestWebConfirmation, "ali",
        {ledgerId, entryId}), "failed-precondition");
    });

  it("itiraz gerekçe ve önerilen tutarla işlenir", async () => {
    const {ledgerId, entryId} = await privateEntry();
    const {token} = await request(ledgerId, entryId);
    await web(fns.respondWebConfirmation, {
      token, action: "dispute", reason: "amount", note: "400 idi",
      suggestedAmountMinor: 40000,
    }, guest);
    const entry = await entryDoc(ledgerId, entryId);
    assert.equal(entry.get("webConfirmation.state"), "disputed");
    assert.equal(entry.get("webConfirmation.reason"), "amount");
    assert.equal(entry.get("webConfirmation.suggestedAmountMinor"), 40000);
    const notes = await notifications("ali");
    assert.match(notes.docs[0].get("message"),
      /Ahmet kayda itiraz etti: Tutar yanlış — “400 idi”/);
    // İtiraz sonrası yeni link istenebilir.
    await request(ledgerId, entryId);
  });

  it("başka e-postayla ve oturumsuz yanıt verilemez", async () => {
    const {ledgerId, entryId} = await privateEntry();
    const {token} = await request(ledgerId, entryId);
    await web(fns.openWebConfirmation, {token}, guest);
    await rejectsWith(web(fns.respondWebConfirmation,
      {token, action: "confirm"}, {uid: "baska", email: "b@example.com"}),
    "permission-denied");
    await rejectsWith(web(fns.respondWebConfirmation,
      {token, action: "confirm"}), "unauthenticated");
    await rejectsWith(web(fns.respondWebConfirmation,
      {token, action: "reject", reason: "yok"}, guest), "invalid-argument");
  });

  it("Pacta hesabı olan kişinin hesabı silinmez", async () => {
    const {ledgerId, entryId} = await privateEntry();
    const {token} = await request(ledgerId, entryId);
    await web(fns.openWebConfirmation, {token},
      {uid: "ayse", email: "ayse@example.com"});
    await web(fns.respondWebConfirmation, {token, action: "confirm"},
      {uid: "ayse", email: "ayse@example.com"});
    await require("firebase-admin").auth().getUser("ayse");
    assert.equal((await db.doc("users/ayse").get()).exists, true);
  });
});

describe("temizlik", () => {
  it("bakım eski istekleri ve yanıtsız misafirleri siler", async () => {
    const {ledgerId, entryId} = await privateEntry();
    const {token} = await request(ledgerId, entryId);
    await createGuest();
    await web(fns.openWebConfirmation, {token}, guest);

    assert.deepEqual(await purgeWebData(new Date()),
      {requests: 0, guests: 0});
    const res = await runMaintenance(new Date(Date.now() + 45 * DAY));
    assert.equal(res.web, 2);
    assert.equal((await db.collection("webRequests").get()).size, 0);
    await assert.rejects(require("firebase-admin").auth().getUser("misafir"),
      (e) => e.code === "auth/user-not-found");
  });

  it("özel defter silinince istekleri de silinir", async () => {
    const {ledgerId, entryId} = await privateEntry();
    await request(ledgerId, entryId);
    await call(fns.deletePrivateLedger, "ali", {ledgerId});
    assert.equal((await db.collection("webRequests").get()).size, 0);
  });
});

describe("sertleştirme", () => {
  it("misafir oturum uygulama komutu çalıştıramaz", async () => {
    const {ledgerId, entryId} = await privateEntry();
    const {token} = await request(ledgerId, entryId);
    await createGuest();
    await web(fns.openWebConfirmation, {token}, guest);
    await rejectsWith(call(fns.createLedger, "misafir",
      {privateName: "Deneme"}), "failed-precondition", /Profiliniz/);
  });

  it("profili olmayan ya da koşulları kabul etmeyen komut çalıştıramaz",
    async () => {
      await rejectsWith(call(fns.myPactaCode, "yeni", {}),
        "failed-precondition", /Profiliniz/);
      await db.doc("users/mallory").set({adSoyad: "Mallory"});
      await rejectsWith(call(fns.myPactaCode, "mallory", {}),
        "failed-precondition", /TERMS_REQUIRED/);
    });

  it("alıcı e-postası belirtilince link yalnızca o adresle açılır",
    async () => {
      const {ledgerId, entryId} = await privateEntry();
      const {token} = await request(ledgerId, entryId,
        {recipientEmail: "Ahmet@Example.com"});
      assert.deepEqual(await web(fns.openWebConfirmation, {token}), {
        status: "open", ownerName: "Ali Veli",
        recipientMasked: "a***@example.com",
      });
      const other = {uid: "baska", email: "b@example.com"};
      assert.equal(
        (await web(fns.openWebConfirmation, {token}, other)).status,
        "otherEmail");
      await rejectsWith(web(fns.respondWebConfirmation,
        {token, action: "confirm"}, other), "permission-denied");

      await createGuest();
      const view = await web(fns.openWebConfirmation, {token}, guest);
      assert.equal(view.status, "open");
      await web(fns.respondWebConfirmation, {token, action: "confirm"}, guest);
      const entry = await entryDoc(ledgerId, entryId);
      assert.equal(entry.get("webConfirmation.recipientSet"), true);
      assert.equal(entry.get("webConfirmation.state"), "confirmed");
      await rejectsWith(request(ledgerId, entryId), "failed-precondition");
    });

  it("geçersiz alıcı e-postası reddedilir", async () => {
    const {ledgerId, entryId} = await privateEntry();
    await rejectsWith(request(ledgerId, entryId, {recipientEmail: "yok"}),
      "invalid-argument");
  });

  it("süresi dolmuş linki açan misafir de işaretlenir", async (t) => {
    const {ledgerId, entryId} = await privateEntry();
    const {token} = await request(ledgerId, entryId);
    await createGuest();
    t.mock.method(webClock, "now", () => new Date(Date.now() + 15 * DAY));
    assert.equal(
      (await web(fns.openWebConfirmation, {token}, guest)).status, "expired");
    assert.equal((await db.doc("webGuests/misafir").get()).exists, true);
  });

  it("bir defterin tarafı olan hesap misafir diye silinmez", async () => {
    const auth = require("firebase-admin").auth();
    await auth.createUser({uid: "hayalet", email: "h@example.com",
      emailVerified: true});
    await db.doc("webGuests/hayalet").set({createdAt: new Date()});
    await db.doc("ledgers/p_hayalet1").set({memberUids: ["hayalet"]});
    assert.equal(await removeGuest("hayalet"), true);
    await auth.getUser("hayalet");
    assert.equal((await db.doc("webGuests/hayalet").get()).exists, false);
  });
});
