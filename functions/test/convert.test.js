// Özel defteri ortak deftere taşıma: açık bakiye (vadeleriyle) karşı tarafın
// onayına gider, özel defter arşivlenir, özel notlar istenmedikçe gitmez.
const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");

const {transferLines} = require("../lib/ledger/commands.js");
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
  today,
  useEmulator,
} = require("./helpers.js");

useEmulator();

async function privateLedger(name = "Ayşe (defterim)") {
  const res = await call(fns.createLedger, "ali", {privateName: name});
  return res.ledgerId;
}

async function write(ledgerId, uid, fields) {
  const entryId = randomUUID();
  await call(fns.createEntry, uid, {
    ledgerId, entryId, asset: "TRY", occurredOn: today, ...fields,
  });
  return entryId;
}

const sharedEntries = async (ledgerId) =>
  (await db.collection(`ledgers/${ledgerId}/entries`).get()).docs
    .map((d) => ({id: d.id, ...d.data()}))
    .sort((x, y) => x.id.localeCompare(y.id));

describe("convertPrivateLedger", () => {
  it("açık bakiye vadeleriyle onaya gider, özel defter arşivlenir",
    async () => {
      const privateId = await privateLedger();
      await lend(privateId, "ali", 100000,
        {dueOn: "2026-10-10", description: "Kira payı"});
      await lend(privateId, "ali", 50000, {description: "Market"});
      // Ayşe 200 ₺ ödedi: önce en eski borçtan düşer.
      await write(privateId, "ali",
        {kind: "payment", iGave: false, amountMinor: 20000});

      const res = await call(fns.convertPrivateLedger, "ali",
        {ledgerId: privateId, counterpartyUid: "ayse"});
      assert.equal(res.transferred, 2);
      assert.equal(res.pending, 2);
      assert.equal(res.displayName, "Ayşe Yılmaz");

      // Aktarılanlar: 800 ₺ vadeli + 500 ₺ vadesiz; özel notlar gitmedi.
      const entries = await sharedEntries(res.ledgerId);
      assert.deepEqual(
        entries.map((e) => [e.amountMinor, e.dueOn, e.state, e.description]),
        [
          [80000, "2026-10-10", "pending", "Önceki kayıtlardan aktarıldı"],
          [50000, null, "pending", "Önceki kayıtlardan kalan bakiye"],
        ]);
      const ledger = await ledgerDoc(res.ledgerId);
      assert.equal(ledger.get("pendingCount"), 2);
      assert.deepEqual(ledger.get("balances"), {});

      // Özel defter kapandı, ortak deftere bağlandı; geçmişi duruyor.
      const priv = await ledgerDoc(privateId);
      assert.equal(priv.get("status"), "closed");
      assert.equal(priv.get("convertedTo"), res.ledgerId);
      assert.deepEqual(priv.get("dueItems"), []);
      assert.equal(priv.get("closedAt"), undefined);
      assert.equal(priv.get("balances.TRY"), 130000);
      await rejectsWith(lend(privateId, "ali", 100), "failed-precondition",
        /kapalı/);

      // Ayşe tek bildirim aldı; iki kayıt gelen kutusunda.
      const notes = (await notifications("ayse")).docs;
      assert.equal(notes.length, 1);
      assert.match(notes[0].get("message"), /2 kayıt onayınızı bekliyor/);
      for (const e of entries) {
        assert.equal((await inboxDoc("ayse", e.id)).exists, true);
      }

      // Ayşe onaylayınca bakiye ve vade ortak defterde.
      for (const e of entries) {
        await call(fns.confirmEntry, "ayse",
          {ledgerId: res.ledgerId, entryId: e.id, expectedVersion: 1});
      }
      const after = await ledgerDoc(res.ledgerId);
      assert.equal(after.get("balances.TRY"), 130000);
      assert.equal(after.get("pendingCount"), 0);
    });

  it("sahibin aleyhine olan bakiye hemen işlenir; zincir sırası doğru",
    async () => {
      const privateId = await privateLedger();
      // Ali, Ayşe'den borç aldı: iki birimde.
      await write(privateId, "ali",
        {kind: "debt", iGave: false, amountMinor: 70000});
      await write(privateId, "ali",
        {kind: "debt", iGave: false, amountMinor: 1000, asset: "USD"});

      const res = await call(fns.convertPrivateLedger, "ali",
        {ledgerId: privateId, counterpartyUid: "ayse"});
      assert.equal(res.transferred, 2);
      assert.equal(res.pending, 0);

      const ledger = await ledgerDoc(res.ledgerId);
      // Ali a tarafı: Ali'nin borcu negatif bakiye.
      assert.equal(ledger.get("balances.TRY"), -70000);
      assert.equal(ledger.get("balances.USD"), -1000);
      assert.equal(ledger.get("head.seq"), 2);
      const seqs = (await sharedEntries(res.ledgerId))
        .map((e) => e.confirmedSeq).sort();
      assert.deepEqual(seqs, [1, 2]);
      const notes = (await notifications("ayse")).docs;
      assert.equal(notes.length, 1);
      assert.match(notes[0].get("message"), /borcunu Pacta'ya kaydetti/);
    });

  it("tekrar çağrı kayıt çoğaltmaz; açıklamalar istenirse gider",
    async () => {
      const privateId = await privateLedger();
      await lend(privateId, "ali", 30000,
        {dueOn: "2026-12-01", description: "Tatil"});
      const input = {
        ledgerId: privateId, counterpartyEmail: "AYSE@example.com",
        includeDescriptions: true,
      };
      const first = await call(fns.convertPrivateLedger, "ali", input);
      const second = await call(fns.convertPrivateLedger, "ali", input);
      assert.equal(second.ledgerId, first.ledgerId);
      assert.equal(second.transferred, 0);
      const entries = await sharedEntries(first.ledgerId);
      assert.equal(entries.length, 1);
      assert.equal(entries[0].description, "Tatil");
      assert.equal(
        (await entryDoc(first.ledgerId, entries[0].id)).get("dueOn"),
        "2026-12-01");
    });

  it("başkasının ya da ortak defter taşınamaz; kendinize taşınamaz",
    async () => {
      const privateId = await privateLedger();
      await rejectsWith(
        call(fns.convertPrivateLedger, "ayse",
          {ledgerId: privateId, counterpartyUid: "ali"}),
        "not-found");
      await rejectsWith(
        call(fns.convertPrivateLedger, "ali",
          {ledgerId: privateId, counterpartyUid: "ali"}),
        "invalid-argument", /kendinizle/i);
      await rejectsWith(
        call(fns.convertPrivateLedger, "ali",
          {ledgerId: privateId, counterpartyUid: "mallory"}),
        "failed-precondition", /doğrulamamış/);
      await rejectsWith(
        call(fns.convertPrivateLedger, "ali",
          {ledgerId: privateId, counterpartyUid: "ayse",
            counterpartyCode: "ABCDEF"}),
        "invalid-argument");
      const {ledgerId: sharedId} = await call(fns.createLedger, "ali",
        {counterpartyUid: "ayse"});
      await rejectsWith(
        call(fns.convertPrivateLedger, "ali",
          {ledgerId: sharedId, counterpartyUid: "ayse"}),
        "failed-precondition", /zaten ortak/);
      // Hiçbiri özel defteri kapatmadı.
      assert.equal((await ledgerDoc(privateId)).get("status"), "active");
    });

  it("aynı anda iki kişiye taşınırsa ikisi de gerçek hedefi döner",
    async () => {
      await require("firebase-admin").auth().createUser(
        {uid: "veli", email: "veli@example.com", emailVerified: true});
      await db.collection("users").doc("veli").set({adSoyad: "Veli"});
      const privateId = await privateLedger();
      await lend(privateId, "ali", 1000);
      const [x, y] = await Promise.all([
        call(fns.convertPrivateLedger, "ali",
          {ledgerId: privateId, counterpartyUid: "ayse"}),
        call(fns.convertPrivateLedger, "ali",
          {ledgerId: privateId, counterpartyUid: "veli"}),
      ]);
      const target = (await ledgerDoc(privateId)).get("convertedTo");
      assert.equal(x.ledgerId, target);
      assert.equal(y.ledgerId, target);
      assert.equal(x.transferred + y.transferred, 1);
    });

  it("boş özel defter: kişi eklenir, defter arşivlenir", async () => {
    const privateId = await privateLedger();
    const res = await call(fns.convertPrivateLedger, "ali",
      {ledgerId: privateId, counterpartyUid: "ayse"});
    assert.equal(res.transferred, 0);
    assert.equal((await ledgerDoc(privateId)).get("convertedTo"), res.ledgerId);
    assert.equal((await notifications("ayse")).size, 0);
  });
});

describe("transferLines", () => {
  const src = (id, fields) => ({
    id, kind: "debt", direction: "aToB", asset: "TRY", amountMinor: 0,
    deltaMinor: 0, occurredOn: "2026-01-01", dueOn: null, description: "",
    linkedEntryId: null, reversedBy: null, confirmedSeq: 0, ...fields,
  });

  it("birim başına en fazla 10 vade; kalanı vadesiz", () => {
    const debts = Array.from({length: 12}, (_, i) => src(`d${i}`, {
      amountMinor: 100, deltaMinor: 100, confirmedSeq: i + 1,
      dueOn: `2026-10-${String(i + 10).padStart(2, "0")}`,
    }));
    const lines = transferLines(debts, "2026-09-27", false);
    assert.equal(lines.length, 11);
    assert.equal(lines.filter((l) => l.dueOn).length, 10);
    assert.equal(lines[10].amountMinor, 200);
    assert.equal(lines.reduce((s, l) => s + l.amountMinor, 0), 1200);
  });

  it("denk bakiye aktarılmaz", () => {
    const lines = transferLines([
      src("d", {amountMinor: 500, deltaMinor: 500}),
      src("p", {kind: "payment", direction: "bToA", amountMinor: 500,
        deltaMinor: -500}),
    ], "2026-09-27", false);
    assert.deepEqual(lines, []);
  });
});
