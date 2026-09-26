// v2 defter komutları, Firestore emulator üzerinde uçtan uca.
// Çalıştırma: cd firestore-tests && npm run functions:test (Java 11+ gerekir).
const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const model = require("../lib/ledger/model.js");
const {ASSETS} = require("../lib/ledger/assets.js");
const {
  call,
  db,
  entryDoc,
  fns,
  inboxDoc,
  lend,
  ledgerDoc,
  limitDay,
  rejectsWith,
  sharedLedger,
  today,
  useEmulator,
} = require("./helpers.js");

useEmulator();

/** Onaylı kayıtların toplamı defterdeki bakiyeye eşit olmalı. */
async function assertBalanceInvariant(ledgerId) {
  const [ledger, entries] = await Promise.all([
    ledgerDoc(ledgerId),
    db.collection("ledgers").doc(ledgerId).collection("entries")
      .where("state", "==", "confirmed").get(),
  ]);
  const sums = {};
  for (const e of entries.docs) {
    sums[e.get("asset")] = (sums[e.get("asset")] ?? 0) + e.get("deltaMinor");
  }
  for (const [asset, value] of Object.entries(ledger.get("balances") ?? {})) {
    assert.equal(value, sums[asset] ?? 0, `bakiye ${asset}`);
  }
  assert.equal(ledger.get("head.seq"), entries.size, "zincir uzunluğu");
}

describe("sözleşmeler", () => {
  it("birimler contracts/assets.json ile aynı", () => {
    const contract = JSON.parse(fs.readFileSync(
      path.join(__dirname, "../../contracts/assets.json"), "utf8"));
    assert.deepEqual(ASSETS, contract);
  });

  it("hash test vektörleri tutuyor", () => {
    const v = JSON.parse(fs.readFileSync(
      path.join(__dirname, "../../contracts/entry_hash_vectors.json"), "utf8"));
    for (const c of v.contentHash) {
      assert.equal(
        model.contentHash(c.ledgerId, c.entryId, c.content, c.version),
        c.expected);
    }
    for (const c of v.chainHash) {
      assert.equal(model.chainHash(c.previous, c.content, c.seq), c.expected);
    }
  });
});

describe("createLedger", () => {
  it("iki kişi için tek ortak defter", async () => {
    const first = await call(
      fns.createLedger, "ali", {counterpartyUid: "ayse"});
    const second = await call(
      fns.createLedger, "ayse", {counterpartyUid: "ali"});
    assert.equal(first.ledgerId, second.ledgerId);
    assert.equal(first.created, true);
    assert.equal(second.created, false);
    const ledger = await ledgerDoc(first.ledgerId);
    assert.equal(ledger.get("sides.a.uid"), "ali");
    assert.equal(ledger.get("sides.b.displayName"), "Ayşe Yılmaz");
  });

  it("kendisi, bilinmeyen kişi ve oturumsuz istek reddedilir", async () => {
    await rejectsWith(
      call(fns.createLedger, "ali", {counterpartyUid: "ali"}),
      "invalid-argument");
    await rejectsWith(
      call(fns.createLedger, "ali", {counterpartyUid: "yok"}), "not-found");
    await rejectsWith(
      call(fns.createLedger, null, {counterpartyUid: "ayse"}),
      "unauthenticated");
  });
});

describe("onay akışı", () => {
  it("lehe kayıt onay bekler, yalnızca karşı taraf onaylar", async () => {
    const ledgerId = await sharedLedger();
    const e = await lend(ledgerId, "ali", 50000);
    assert.equal(e.state, "pending");
    assert.equal((await ledgerDoc(ledgerId)).get("pendingCount"), 1);
    const inbox = await inboxDoc("ayse", e.entryId);
    assert.equal(inbox.get("myDeltaMinor"), -50000);

    const key = {ledgerId, entryId: e.entryId, expectedVersion: 1};
    await rejectsWith(
      call(fns.confirmEntry, "ali", key), "failed-precondition");
    await rejectsWith(
      call(fns.confirmEntry, "mallory", key), "permission-denied");

    await call(fns.confirmEntry, "ayse", key);
    const ledger = await ledgerDoc(ledgerId);
    assert.equal(ledger.get("balances.TRY"), 50000);
    assert.equal(ledger.get("pendingCount"), 0);
    const entry = await entryDoc(ledgerId, e.entryId);
    assert.equal(entry.get("state"), "confirmed");
    assert.equal(
      ledger.get("head.chainHash"),
      model.chainHash("", entry.get("contentHash"), 1));
    assert.equal((await inboxDoc("ayse", e.entryId)).exists, false);

    const again = await call(fns.confirmEntry, "ayse", key);
    assert.equal(again.state, "confirmed");
    assert.equal((await ledgerDoc(ledgerId)).get("balances.TRY"), 50000);
    await assertBalanceInvariant(ledgerId);
  });

  it("eski sürüme bakılarak verilen onay reddedilir", async () => {
    const ledgerId = await sharedLedger();
    const e = await lend(ledgerId, "ali", 45000);
    await call(fns.reviseEntry, "ali",
      {ledgerId, entryId: e.entryId, expectedVersion: 1, amountMinor: 40000});
    await rejectsWith(
      call(fns.confirmEntry, "ayse",
        {ledgerId, entryId: e.entryId, expectedVersion: 1}),
      "failed-precondition", /STALE_VERSION/);
    await call(fns.confirmEntry, "ayse",
      {ledgerId, entryId: e.entryId, expectedVersion: 2});
    assert.equal((await ledgerDoc(ledgerId)).get("balances.TRY"), 40000);
    const revisions = await db.collection("ledgers").doc(ledgerId)
      .collection("entries").doc(e.entryId).collection("revisions").get();
    assert.equal(revisions.size, 2);
    await assertBalanceInvariant(ledgerId);
  });

  it("aynı anda iki onay bakiyeyi bir kez değiştirir", async () => {
    const ledgerId = await sharedLedger();
    const e = await lend(ledgerId, "ali", 12345);
    const key = {ledgerId, entryId: e.entryId, expectedVersion: 1};
    await Promise.all([
      call(fns.confirmEntry, "ayse", key),
      call(fns.confirmEntry, "ayse", key),
    ]);
    assert.equal((await ledgerDoc(ledgerId)).get("balances.TRY"), 12345);
    await assertBalanceInvariant(ledgerId);
  });

  it("itiraz kaydı girene döner, düzeltme yeniden onaya gider", async () => {
    const ledgerId = await sharedLedger();
    const e = await lend(ledgerId, "ali", 45000);
    await call(fns.disputeEntry, "ayse", {
      ledgerId, entryId: e.entryId, expectedVersion: 1,
      reason: "amount", note: "Toplam 400", suggestedAmountMinor: 40000,
    });
    let entry = await entryDoc(ledgerId, e.entryId);
    assert.equal(entry.get("state"), "disputed");
    assert.equal(entry.get("awaitingSide"), "a");
    assert.equal((await inboxDoc("ali", e.entryId)).get("type"), "reviseEntry");
    assert.equal((await inboxDoc("ayse", e.entryId)).exists, false);

    await call(fns.reviseEntry, "ali",
      {ledgerId, entryId: e.entryId, expectedVersion: 1, amountMinor: 40000});
    entry = await entryDoc(ledgerId, e.entryId);
    assert.equal(entry.get("state"), "pending");
    assert.equal(entry.get("version"), 2);
    assert.equal(entry.get("dispute"), null);
    assert.equal((await inboxDoc("ayse", e.entryId)).get("version"), 2);
    assert.equal((await inboxDoc("ali", e.entryId)).exists, false);
  });

  it("ret bakiyeyi değiştirmez; yalnızca kaydı giren geri çeker", async () => {
    const ledgerId = await sharedLedger();
    const rejected = await lend(ledgerId, "ali", 10000);
    await call(fns.rejectEntry, "ayse", {
      ledgerId, entryId: rejected.entryId, expectedVersion: 1,
      reason: "notAgreed",
    });
    const cancelled = await lend(ledgerId, "ali", 20000);
    await rejectsWith(
      call(fns.cancelEntry, "ayse",
        {ledgerId, entryId: cancelled.entryId, expectedVersion: 1}),
      "permission-denied");
    await call(fns.cancelEntry, "ali",
      {ledgerId, entryId: cancelled.entryId, expectedVersion: 1});

    const ledger = await ledgerDoc(ledgerId);
    assert.equal(ledger.get("pendingCount"), 0);
    assert.equal(ledger.get("balances.TRY"), undefined);
    assert.equal((await entryDoc(ledgerId, rejected.entryId)).get("state"),
      "rejected");
    assert.equal((await inboxDoc("ayse", cancelled.entryId)).exists, false);
    await rejectsWith(
      call(fns.confirmEntry, "ayse",
        {ledgerId, entryId: rejected.entryId, expectedVersion: 1}),
      "failed-precondition");
  });
});

describe("aleyhe kayıt", () => {
  it("alacaklının 'ödeme aldım' kaydı onay beklemeden işlenir", async () => {
    const ledgerId = await sharedLedger();
    const debt = await lend(ledgerId, "ali", 50000);
    await call(fns.confirmEntry, "ayse",
      {ledgerId, entryId: debt.entryId, expectedVersion: 1});

    const res = await call(fns.createEntry, "ali", {
      ledgerId, entryId: randomUUID(), kind: "payment", iGave: false,
      asset: "TRY", amountMinor: 20000, occurredOn: today,
      linkedEntryId: debt.entryId,
    });
    assert.equal(res.state, "confirmed");
    const ledger = await ledgerDoc(ledgerId);
    assert.equal(ledger.get("balances.TRY"), 30000);
    assert.equal(ledger.get("pendingCount"), 0);
    const notes = await db.collection("users").doc("ayse")
      .collection("notifications").where("type", "==", "entryRecorded").get();
    assert.equal(notes.size, 1);
    assert.match(notes.docs[0].get("message"), /ödeme aldığını kaydetti/);
    await assertBalanceInvariant(ledgerId);
  });

  it("borçlunun 'ödeme yaptım' kaydı onay bekler", async () => {
    const ledgerId = await sharedLedger();
    const res = await call(fns.createEntry, "ayse", {
      ledgerId, entryId: randomUUID(), kind: "payment", iGave: true,
      asset: "TRY", amountMinor: 25000, occurredOn: today,
    });
    assert.equal(res.state, "pending");
    const notes = await db.collection("users").doc("ali")
      .collection("notifications").get();
    assert.match(notes.docs[0].get("message"), /ödeme yaptığını bildirdi/);
  });
});

describe("ters kayıt", () => {
  it("onaylı kayıt ters kayıtla düzeltilir, iki kez düzeltilemez", async () => {
    const ledgerId = await sharedLedger();
    const debt = await lend(ledgerId, "ali", 50000);
    await call(fns.confirmEntry, "ayse",
      {ledgerId, entryId: debt.entryId, expectedVersion: 1});

    // Ayşe'nin lehine: Ali'nin onayını bekler.
    const reversalId = randomUUID();
    const res = await call(fns.reverseEntry, "ayse",
      {ledgerId, entryId: debt.entryId, reversalId, note: "Yanlış kişi"});
    assert.equal(res.state, "pending");
    assert.equal((await entryDoc(ledgerId, debt.entryId))
      .get("reversalPendingId"), reversalId);
    await rejectsWith(
      call(fns.reverseEntry, "ali",
        {ledgerId, entryId: debt.entryId, reversalId: randomUUID()}),
      "failed-precondition");

    await call(fns.confirmEntry, "ali",
      {ledgerId, entryId: reversalId, expectedVersion: 1});
    assert.equal((await ledgerDoc(ledgerId)).get("balances.TRY"), 0);
    const original = await entryDoc(ledgerId, debt.entryId);
    assert.equal(original.get("reversedBy"), reversalId);
    assert.equal(original.get("state"), "confirmed");
    await assertBalanceInvariant(ledgerId);
  });

  it("aleyhe ters kayıt hemen işlenir", async () => {
    const ledgerId = await sharedLedger();
    const debt = await lend(ledgerId, "ali", 30000);
    await call(fns.confirmEntry, "ayse",
      {ledgerId, entryId: debt.entryId, expectedVersion: 1});
    const res = await call(fns.reverseEntry, "ali",
      {ledgerId, entryId: debt.entryId, reversalId: randomUUID()});
    assert.equal(res.state, "confirmed");
    assert.equal((await ledgerDoc(ledgerId)).get("balances.TRY"), 0);
    await assertBalanceInvariant(ledgerId);
  });
});

describe("özel defter", () => {
  it("kayıtlar hemen işlenir, kimseye bildirim gitmez", async () => {
    const {ledgerId} = await call(fns.createLedger, "ali",
      {privateName: "Bakkal Hasan"});
    const ledger = await ledgerDoc(ledgerId);
    assert.equal(ledger.get("mode"), "private");
    assert.deepEqual(ledger.get("memberUids"), ["ali"]);

    const res = await call(fns.createEntry, "ali", {
      ledgerId, entryId: randomUUID(), kind: "debt", iGave: false,
      asset: "GAU", amountMinor: 2125, occurredOn: today,
    });
    assert.equal(res.state, "confirmed");
    assert.equal((await ledgerDoc(ledgerId)).get("balances.GAU"), -2125);
    await assertBalanceInvariant(ledgerId);
    await rejectsWith(
      call(fns.createEntry, "ayse", {
        ledgerId, entryId: randomUUID(), kind: "debt", iGave: true,
        asset: "TRY", amountMinor: 100, occurredOn: today,
      }),
      "permission-denied");
  });
});

describe("sınırlar", () => {
  it("bir kişide 50 onay bekleyen kayıttan fazlası açılamaz", async () => {
    const ledgerId = await sharedLedger();
    await db.collection("ledgers").doc(ledgerId).update({pendingCount: 50});
    await rejectsWith(lend(ledgerId, "ali", 100), "resource-exhausted",
      /onay bekleyen çok fazla/);
    // Aleyhe kayıt onay beklemediği için sınırdan etkilenmez.
    const res = await call(fns.createEntry, "ali", {
      ledgerId, entryId: randomUUID(), kind: "debt", iGave: false,
      asset: "TRY", amountMinor: 100, occurredOn: today,
    });
    assert.equal(res.state, "confirmed");
  });

  it("bakiye üst sınırı aşılamaz", async () => {
    const ledgerId = await sharedLedger();
    await db.collection("ledgers").doc(ledgerId)
      .update({"balances.TRY": 1e15 - 50});
    // Aleyhe kayıt hemen işlenir; sınırı aşarsa reddedilir.
    await rejectsWith(call(fns.createEntry, "ayse", {
      ledgerId, entryId: randomUUID(), kind: "debt", iGave: false,
      asset: "TRY", amountMinor: 100, occurredOn: today,
    }), "failed-precondition", /üst sınır/);
  });

  it("günlük kayıt ve düzeltme sınırı", async () => {
    const ledgerId = await sharedLedger();
    await db.collection("rateLimits").doc("entries_ali")
      .set({day: limitDay, count: 300});
    await rejectsWith(lend(ledgerId, "ali", 100), "resource-exhausted");
  });
});

describe("girdi doğrulama ve tekrar", () => {
  it("geçersiz girdiler reddedilir", async () => {
    const ledgerId = await sharedLedger();
    const base = {
      ledgerId, entryId: randomUUID(), kind: "debt", iGave: true,
      asset: "TRY", amountMinor: 100, occurredOn: today,
    };
    for (const bad of [
      {amountMinor: 1500.5},
      {amountMinor: 0},
      {amountMinor: -5},
      {asset: "BTC"},
      {occurredOn: "2026-02-30"},
      {dueOn: "2026-09-01"},
      {occurredOn: "9999-12-31"},
      {occurredOn: "0100-01-01"},
      {dueOn: "2099-01-01"},
      {extra: true},
    ]) {
      await rejectsWith(
        call(fns.createEntry, "ali", {...base, ...bad}), "invalid-argument");
    }
  });

  it("aynı kimlikle tekrar oluşturma tek kayıt üretir", async () => {
    const ledgerId = await sharedLedger();
    const entryId = randomUUID();
    const data = {
      ledgerId, entryId, kind: "debt", iGave: true, asset: "TRY",
      amountMinor: 700, occurredOn: today,
    };
    await call(fns.createEntry, "ali", data);
    await call(fns.createEntry, "ali", data);
    assert.equal((await ledgerDoc(ledgerId)).get("pendingCount"), 1);
    await rejectsWith(call(fns.createEntry, "ayse", data), "already-exists");
  });
});
