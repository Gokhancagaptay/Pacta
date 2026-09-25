// Vade özeti, elle hatırlatma ve günlük vade hatırlatmaları (emulator).
const {afterEach, describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");

const {recomputeDue} = require("../lib/ledger/due.js");
const reminders = require("../lib/ledger/reminders.js");
const {
  call,
  db,
  fft,
  fns,
  lend,
  ledgerDoc,
  notifications,
  rejectsWith,
  sharedLedger,
  today,
  useEmulator,
} = require("./helpers.js");

useEmulator();

const at = (iso) => {
  reminders.clock.now = () => new Date(iso);
};
const noon = `${today}T12:00:00+03:00`;
afterEach(() => at(noon));
at(noon);

/** Ali, Ayşe'ye borç verir; Ayşe onaylar. */
async function confirmedLoan(ledgerId, amountMinor, extra = {}) {
  const e = await lend(ledgerId, "ali", amountMinor, extra);
  await call(fns.confirmEntry, "ayse",
    {ledgerId, entryId: e.entryId, expectedVersion: 1});
  await recomputeDue(ledgerId);
  return e;
}

const remind = (uid, ledgerId) =>
  call(fns.sendReminder, uid, {ledgerId});

const pushQueue = () => db.collection("pushQueue").get();

describe("vade özeti", () => {
  it("onaylı vadeli borç deftere yazılır, ödeme düşer", async () => {
    const ledgerId = await sharedLedger();
    const e = await confirmedLoan(ledgerId, 50000,
      {occurredOn: "2026-09-01", dueOn: "2026-09-10"});
    let ledger = await ledgerDoc(ledgerId);
    assert.deepEqual(ledger.get("dueItems"), [{
      entryId: e.entryId, asset: "TRY", debtorSide: "b", openMinor: 50000,
      dueOn: "2026-09-10", description: "Yemek",
    }]);
    assert.deepEqual(ledger.get("dueDates"), ["2026-09-10"]);

    await call(fns.createEntry, "ali", {
      ledgerId, entryId: randomUUID(), kind: "payment", iGave: false,
      asset: "TRY", amountMinor: 20000, occurredOn: today,
    });
    await recomputeDue(ledgerId);
    ledger = await ledgerDoc(ledgerId);
    assert.equal(ledger.get("dueItems")[0].openMinor, 30000);
  });

  it("tetikleyici onaylanan kayıtta yeniden hesaplar", async () => {
    const ledgerId = await sharedLedger();
    const e = await lend(ledgerId, "ali", 1000, {dueOn: "2026-10-01"});
    await call(fns.confirmEntry, "ayse",
      {ledgerId, entryId: e.entryId, expectedVersion: 1});
    const path = `ledgers/${ledgerId}/entries/${e.entryId}`;
    const change = fft.makeChange(
      fft.firestore.makeDocumentSnapshot({state: "pending"}, path),
      fft.firestore.makeDocumentSnapshot({state: "confirmed"}, path));
    await fft.wrap(fns.onLedgerEntryWritten)({
      data: change,
      params: {ledgerId, entryId: e.entryId},
    });
    assert.equal((await ledgerDoc(ledgerId)).get("dueItems").length, 1);
  });
});

describe("sendReminder", () => {
  it("borçluya tutarsız, nazik bildirim gider; tekrarı sınırlanır",
    async () => {
      const ledgerId = await sharedLedger();
      await confirmedLoan(ledgerId, 50000);
      const res = await remind("ali", ledgerId);
      assert.deepEqual(res,
        {kind: "balance", queued: false, nextOn: "2026-10-02"});

      const notes = await notifications("ayse");
      assert.equal(notes.size, 2); // onay isteği + hatırlatma
      const note = notes.docs.find((d) => d.get("type") === "reminder");
      assert.match(note.get("message"), /Ali Veli ile ortak hesabınızda/);
      assert.doesNotMatch(note.get("message"), /₺|500/);
      assert.equal(note.get("route"), `/l/${ledgerId}`);
      assert.equal(note.get("entryId"), null);
      const ledger = await ledgerDoc(ledgerId);
      assert.equal(ledger.get("reminders.a.lastOn"), today);

      await rejectsWith(remind("ali", ledgerId), "resource-exhausted",
        /Bir sonraki hatırlatma: 2 Ekim/);
      at("2026-10-02T10:00:00+03:00");
      assert.equal((await remind("ali", ledgerId)).kind, "balance");
    });

  it("borçlu olan ya da bekleyeni olmayan hatırlatamaz", async () => {
    const ledgerId = await sharedLedger();
    await rejectsWith(remind("ali", ledgerId), "failed-precondition",
      /hatırlatılacak bir şey yok/);
    await confirmedLoan(ledgerId, 50000);
    await rejectsWith(remind("ayse", ledgerId), "failed-precondition");
    await rejectsWith(remind("mallory", ledgerId), "permission-denied");
  });

  it("yanıt bekleyen kayıt için hatırlatır", async () => {
    const ledgerId = await sharedLedger();
    await lend(ledgerId, "ali", 1000);
    const res = await remind("ali", ledgerId);
    assert.equal(res.kind, "pending");
    const notes = await notifications("ayse");
    const note = notes.docs.find((d) => d.get("type") === "reminder");
    assert.match(note.get("message"), /yanıtınızı bekleyen 1 kayıt/);
  });

  it("vadesi geçmişse 3 günde bir hatırlatılabilir", async () => {
    const ledgerId = await sharedLedger();
    await confirmedLoan(ledgerId, 50000,
      {occurredOn: "2026-09-01", dueOn: "2026-09-10"});
    assert.equal((await remind("ali", ledgerId)).kind, "overdue");
    at("2026-09-27T12:00:00+03:00");
    await rejectsWith(remind("ali", ledgerId), "resource-exhausted");
    at("2026-09-28T12:00:00+03:00");
    assert.equal((await remind("ali", ledgerId)).kind, "overdue");
  });

  it("gece gönderilen hatırlatmanın push'u sabaha kalır", async () => {
    const ledgerId = await sharedLedger();
    await confirmedLoan(ledgerId, 50000);
    at(`${today}T23:30:00+03:00`);
    const res = await remind("ali", ledgerId);
    assert.equal(res.queued, true);
    const queue = await pushQueue();
    assert.equal(queue.size, 1);
    assert.equal(
      queue.docs[0].get("sendAfter").toDate().toISOString(),
      "2026-09-26T06:00:00.000Z");

    await reminders.runDailyReminders(new Date("2026-09-26T09:00:00+03:00"));
    assert.equal((await pushQueue()).size, 0);
  });

  it("sessize alan alıcıya push gitmez, bildirim listesine düşer",
    async () => {
      const ledgerId = await sharedLedger();
      await confirmedLoan(ledgerId, 50000);
      await db.collection("users").doc("ayse")
        .set({reminderMutes: {[ledgerId]: true}}, {merge: true});
      at(`${today}T23:30:00+03:00`);
      await remind("ali", ledgerId);
      assert.equal((await pushQueue()).size, 0);
      const notes = await notifications("ayse");
      assert.ok(notes.docs.some((d) => d.get("type") === "reminder"));
    });

  it("özel defterde ve günlük sınırda reddedilir", async () => {
    const {ledgerId} = await call(fns.createLedger, "ali",
      {privateName: "Bakkal Hasan"});
    await rejectsWith(remind("ali", ledgerId), "failed-precondition",
      /Özel defterde/);

    const shared = await sharedLedger();
    await confirmedLoan(shared, 1000);
    await db.collection("rateLimits").doc("reminders_ali")
      .set({day: today, count: 10});
    await rejectsWith(remind("ali", shared), "resource-exhausted",
      /sınırına ulaştınız/);
  });
});

describe("günlük vade hatırlatmaları", () => {
  const run = (day) =>
    reminders.runDailyReminders(new Date(`${day}T09:00:00+03:00`));
  const dueNotes = async (uid) =>
    (await notifications(uid)).docs.filter(
      (d) => d.get("type") === "dueReminder");

  it("vade günü iki tarafa, bir kez gider", async () => {
    const ledgerId = await sharedLedger();
    await confirmedLoan(ledgerId, 50000, {dueOn: "2026-09-30"});
    await run("2026-09-30");
    const [ali, ayse] = [await dueNotes("ali"), await dueNotes("ayse")];
    assert.equal(ali.length, 1);
    assert.equal(ayse.length, 1);
    assert.match(ayse[0].get("message"), /Ali Veli ile hesabınızda bugün/);
    assert.match(ali[0].get("message"), /Ayşe Yılmaz ile hesabınızda bugün/);

    await run("2026-09-30");
    assert.equal((await dueNotes("ayse")).length, 1);
  });

  it("vadeden önce yalnızca borçluya, en acil olan", async () => {
    const ledgerId = await sharedLedger();
    await confirmedLoan(ledgerId, 1000,
      {occurredOn: "2026-09-01", dueOn: "2026-09-23"});
    await confirmedLoan(ledgerId, 1000, {dueOn: "2026-09-29"});
    await run("2026-09-26");
    assert.equal((await dueNotes("ali")).length, 0);
    const ayse = await dueNotes("ayse");
    assert.equal(ayse.length, 1);
    assert.equal(ayse[0].get("title"), "Vadesi geçmiş kayıt");
  });
});
