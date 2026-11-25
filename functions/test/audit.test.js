// Bakiye ve zincir tutarlılık denetimi: gerçek komut akışlarından sonra
// hiçbir sorun yok; doğrudan (yönetici SDK'sıyla) bozulan veri doğru kodla
// bildirilir.
const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");
const {FieldValue} = require("firebase-admin/firestore");

const {auditLedger, auditStoredLedger} = require("../lib/ledger/audit.js");
const {contentHash} = require("../lib/ledger/model.js");
const {
  call,
  db,
  entryDoc,
  fft,
  fns,
  lend,
  ledgerDoc,
  sharedLedger,
  today,
  useEmulator,
} = require("./helpers.js");

useEmulator();

const key = (ledgerId, entryId, expectedVersion = 1) =>
  ({ledgerId, entryId, expectedVersion});
const entryRef = (ledgerId, entryId) =>
  db.doc(`ledgers/${ledgerId}/entries/${entryId}`);

async function problems(ledgerId) {
  const res = await auditStoredLedger(ledgerId, 1000);
  assert.equal(res.status, "audited");
  return res.problems;
}

async function clean(ledgerId, step) {
  assert.deepEqual(await problems(ledgerId), [], step);
}

const codes = async (ledgerId) =>
  (await problems(ledgerId)).map((p) => p.code).sort();

/** Ödeme ya da borç kaydı (lend dışındaki alanlarla). */
async function entry(ledgerId, uid, fields) {
  const entryId = randomUUID();
  const res = await call(fns.createEntry, uid, {
    ledgerId, entryId, asset: "TRY", occurredOn: today, ...fields,
  });
  return {entryId, ...res};
}

async function reverse(ledgerId, uid, entryId) {
  const reversalId = randomUUID();
  const res = await call(fns.reverseEntry, uid,
    {ledgerId, entryId, reversalId});
  return {reversalId, ...res};
}

describe("gerçek akışlar tutarlı", () => {
  it("oluşturma, onay, itiraz-düzenleme-onay, ret, geri çekme, aleyhe kayıt",
    async () => {
      const L = await sharedLedger();
      await clean(L, "boş defter");

      const a = await lend(L, "ali", 10000);
      await clean(L, "bekleyen kayıt");
      await call(fns.confirmEntry, "ayse", key(L, a.entryId));
      await clean(L, "onay");

      const b = await lend(L, "ali", 5000, {dueOn: "2026-12-01"});
      await call(fns.disputeEntry, "ayse", {...key(L, b.entryId),
        reason: "amount", suggestedAmountMinor: 4000});
      await clean(L, "itiraz");
      await call(fns.reviseEntry, "ali", {...key(L, b.entryId),
        amountMinor: 4000, description: "Yarısı"});
      await clean(L, "düzenleme");
      // İtirazsız ikinci düzenleme: sürüm 3.
      await call(fns.reviseEntry, "ali", {...key(L, b.entryId, 2),
        asset: "USD"});
      await clean(L, "birim değişikliği");
      await call(fns.confirmEntry, "ayse", key(L, b.entryId, 3));
      await clean(L, "düzenlenen kaydın onayı");

      const c = await lend(L, "ali", 700);
      await call(fns.rejectEntry, "ayse",
        {...key(L, c.entryId), reason: "notAgreed"});
      await clean(L, "ret");

      const d = await lend(L, "ali", 800);
      await call(fns.cancelEntry, "ali", key(L, d.entryId));
      await clean(L, "geri çekme");

      const e = await lend(L, "ali", 900);
      await call(fns.disputeEntry, "ayse",
        {...key(L, e.entryId), reason: "other"});
      await call(fns.cancelEntry, "ali", key(L, e.entryId));
      await clean(L, "itiraz edilen kaydı geri çekme");

      const f = await lend(L, "ayse", 300, {asset: "EUR"});
      await call(fns.confirmEntry, "ali", key(L, f.entryId));
      await clean(L, "karşı tarafın kaydı");

      // Alacaklının "ödeme aldım" kaydı: onay beklemeden işlenir.
      const paid = await entry(L, "ali", {kind: "payment", iGave: false,
        amountMinor: 2500, linkedEntryId: a.entryId});
      assert.equal(paid.state, "confirmed");
      await clean(L, "aleyhe bağlı ödeme");
      // Borçlunun "ödeme yaptım" kaydı onay bekler.
      const pays = await entry(L, "ayse", {kind: "payment", iGave: true,
        amountMinor: 1000});
      assert.equal(pays.state, "pending");
      await clean(L, "bekleyen ödeme");

      const ledger = await ledgerDoc(L);
      assert.equal(ledger.get("head.seq"), 4);
      assert.equal(ledger.get("pendingCount"), 1);
    });

  it("ters kayıt: bekleyen (ret, itiraz, geri çekme, onay) ve aleyhe",
    async () => {
      const L = await sharedLedger();
      const debt = await lend(L, "ali", 50000);
      await call(fns.confirmEntry, "ayse", key(L, debt.entryId));

      const r1 = await reverse(L, "ayse", debt.entryId);
      assert.equal(r1.state, "pending");
      await clean(L, "bekleyen ters kayıt");
      await call(fns.rejectEntry, "ali",
        {...key(L, r1.reversalId), reason: "notAgreed"});
      await clean(L, "reddedilen ters kayıt");

      const r2 = await reverse(L, "ayse", debt.entryId);
      await call(fns.disputeEntry, "ali",
        {...key(L, r2.reversalId), reason: "other"});
      await clean(L, "itiraz edilen ters kayıt");
      await call(fns.cancelEntry, "ayse", key(L, r2.reversalId));
      await clean(L, "geri çekilen ters kayıt");

      const r3 = await reverse(L, "ayse", debt.entryId);
      await call(fns.confirmEntry, "ali", key(L, r3.reversalId));
      await clean(L, "onaylanan ters kayıt");
      assert.equal((await ledgerDoc(L)).get("balances.TRY"), 0);

      // Aleyhe ters kayıt hemen işlenir; bağlı ödemesi olan borç.
      const gold = await lend(L, "ali", 1500, {asset: "GAU"});
      await call(fns.confirmEntry, "ayse", key(L, gold.entryId));
      await entry(L, "ali", {kind: "payment", iGave: false, asset: "GAU",
        amountMinor: 500, linkedEntryId: gold.entryId});
      const r4 = await reverse(L, "ali", gold.entryId);
      assert.equal(r4.state, "confirmed");
      await clean(L, "aleyhe ters kayıt");
    });

  it("aynı anda gelen kayıtlar ve onaylar", async () => {
    const L = await sharedLedger();
    // Ali ve Ayşe sırayla kayıt girer; her kaydı karşı taraf onaylar.
    const made = await Promise.all([1, 2, 3].map((i) =>
      lend(L, i % 2 ? "ali" : "ayse", 1000 * i)));
    await clean(L, "eşzamanlı kayıtlar");
    await Promise.all(made.map((m, i) => call(fns.confirmEntry,
      i % 2 ? "ali" : "ayse", key(L, m.entryId))));
    await clean(L, "eşzamanlı onaylar");
    assert.equal((await ledgerDoc(L)).get("head.seq"), 3);
  });

  it("özel defter, ters kaydı ve ortak deftere taşıma", async () => {
    const shared = await sharedLedger();
    const before = await lend(shared, "ali", 1000);
    await call(fns.confirmEntry, "ayse", key(shared, before.entryId));
    await lend(shared, "ayse", 200);

    const {ledgerId: P} = await call(fns.createLedger, "ali",
      {privateName: "Ayşe (defterim)"});
    await clean(P, "boş özel defter");
    await lend(P, "ali", 100000, {dueOn: "2026-12-10"});
    await entry(P, "ali", {kind: "payment", iGave: false,
      amountMinor: 30000});
    const wrong = await lend(P, "ali", 5000);
    await reverse(P, "ali", wrong.entryId);
    await lend(P, "ali", 20000, {asset: "USD"});
    await lend(P, "ali", 1500, {asset: "GAU"});
    // Ali'nin borçları: taşımada onay beklemeden işlenir.
    await lend(P, "ali", 3, {asset: "CEYREK", iGave: false});
    await lend(P, "ali", 4000, {asset: "EUR", iGave: false});
    await clean(P, "özel defter");

    const res = await call(fns.convertPrivateLedger, "ali",
      {ledgerId: P, counterpartyUid: "ayse"});
    assert.equal(res.ledgerId, shared);
    assert.equal(res.transferred, 5);
    assert.equal(res.pending, 3);
    await clean(P, "taşınan (kapalı) özel defter");
    await clean(shared, "taşıma sonrası ortak defter");

    const moved = (await db.collection(`ledgers/${shared}/entries`)
      .where("state", "==", "pending").get()).docs
      .filter((d) => d.id.startsWith("t_"))
      .map((d) => d.id)
      .sort();
    assert.equal(moved.length, 3);
    await call(fns.confirmEntry, "ayse", key(shared, moved[0]));
    await clean(shared, "taşınan kaydın onayı");
    await call(fns.disputeEntry, "ayse",
      {...key(shared, moved[1]), reason: "amount"});
    await call(fns.reviseEntry, "ali",
      {...key(shared, moved[1]), amountMinor: 60000});
    await call(fns.confirmEntry, "ayse", key(shared, moved[1], 2));
    await clean(shared, "düzenlenip onaylanan taşıma kaydı");
    await call(fns.rejectEntry, "ayse",
      {...key(shared, moved[2]), reason: "notAgreed"});
    await clean(shared, "reddedilen taşıma kaydı");
    // Taşınan kayıt da ters kayıtla düzeltilebilir.
    await reverse(shared, "ayse", moved[0]);
    await clean(shared, "taşıma kaydının bekleyen ters kaydı");
  });

  it("web itirazı özel defterin bakiyesini ve zincirini bozmaz", async () => {
    const {ledgerId} = await call(fns.createLedger, "ali",
      {privateName: "Ahmet"});
    const {entryId} = await lend(ledgerId, "ali", 50000);
    const {url} = await call(fns.requestWebConfirmation, "ali",
      {ledgerId, entryId});
    await clean(ledgerId, "web onayı istendi");
    await fft.wrap(fns.respondWebConfirmation)({
      data: {token: url.split("/o/")[1], action: "dispute",
        reason: "amount", note: "", suggestedAmountMinor: 40000},
      auth: {uid: "misafir",
        token: {email: "ahmet@example.com", email_verified: true}},
      rawRequest: {ip: "198.51.100.7", headers: {}},
    });
    const e = await entryDoc(ledgerId, entryId);
    assert.equal(e.get("webConfirmation.state"), "disputed");
    assert.equal(e.get("state"), "confirmed");
    await clean(ledgerId, "web itirazı");
  });

  it("hesap silme defteri kapatır; açık kayıtlar tutarlı kapanır",
    async () => {
      const L = await sharedLedger();
      const debt = await lend(L, "ali", 50000);
      await call(fns.confirmEntry, "ayse", key(L, debt.entryId));
      const other = await lend(L, "ayse", 7000);
      await call(fns.confirmEntry, "ali", key(L, other.entryId));
      await lend(L, "ali", 1000);
      await lend(L, "ayse", 2000);
      const disputed = await lend(L, "ayse", 3000);
      await call(fns.disputeEntry, "ali",
        {...key(L, disputed.entryId), reason: "date"});
      await reverse(L, "ayse", debt.entryId);
      await reverse(L, "ali", other.entryId);
      await clean(L, "silme öncesi");

      await call(fns.deleteAccount, "ali", {},
        {authTime: Math.floor(Date.now() / 1000) - 30});
      const ledger = await ledgerDoc(L);
      assert.equal(ledger.get("status"), "closed");
      assert.equal(ledger.get("pendingCount"), 0);
      await clean(L, "hesap silme ile kapanan defter");

      // İki taraf da silerse defter tamamen gider.
      await call(fns.deleteAccount, "ayse", {},
        {authTime: Math.floor(Date.now() / 1000) - 30});
      assert.deepEqual(await auditStoredLedger(L, 1000), {status: "missing"});
    });
});

describe("bozulan veri bildirilir", () => {
  /** Üç onaylı (sıra 1-3) ve bir bekleyen kayıtlı tutarlı defter. */
  async function base() {
    const L = await sharedLedger();
    const ids = [];
    for (const amount of [10000, 2000, 3000]) {
      const {entryId} = await lend(L, "ali", amount);
      await call(fns.confirmEntry, "ayse", key(L, entryId));
      ids.push(entryId);
    }
    const p = await lend(L, "ali", 400);
    await clean(L, "bozmadan önce");
    return {L, a: ids[0], b: ids[1], c: ids[2], p: p.entryId};
  }

  it("yanlış bakiye", async () => {
    const {L} = await base();
    await db.doc(`ledgers/${L}`).update({
      "balances.TRY": FieldValue.increment(1),
      "balances.USD": 5,
    });
    assert.deepEqual(await problems(L), [
      {code: "BALANCE_MISMATCH", ledgerId: L, asset: "TRY",
        expected: 15000, actual: 15001},
      {code: "BALANCE_MISMATCH", ledgerId: L, asset: "USD",
        expected: 0, actual: 5},
    ]);
  });

  it("yanlış bekleyen sayısı", async () => {
    const {L} = await base();
    await db.doc(`ledgers/${L}`).update({pendingCount: 0});
    assert.deepEqual(await problems(L), [{code: "PENDING_COUNT_MISMATCH",
      ledgerId: L, expected: 1, actual: 0}]);
  });

  it("özeti güncellenmeden değiştirilen tutar", async () => {
    const {L, b} = await base();
    await entryRef(L, b).update({amountMinor: 2500});
    assert.deepEqual(await problems(L), [
      {code: "DELTA_MISMATCH", ledgerId: L, entryId: b,
        expected: 2500, actual: 2000},
      {code: "CONTENT_HASH_MISMATCH", ledgerId: L, entryId: b},
    ]);
  });

  it("tutar ve etki birlikte değişirse bakiye tutmaz", async () => {
    const {L, b} = await base();
    await entryRef(L, b).update({amountMinor: 2500, deltaMinor: 2500});
    assert.deepEqual(await codes(L),
      ["BALANCE_MISMATCH", "CONTENT_HASH_MISMATCH"]);
  });

  it("özeti ve bakiyesi yeniden hesaplanmış sahte tutar zincirde yakalanır",
    async () => {
      const {L, b} = await base();
      const e = (await entryDoc(L, b)).data();
      const hash = contentHash(L, b, {...e, amountMinor: 2500}, e.version);
      await entryRef(L, b).update(
        {amountMinor: 2500, deltaMinor: 2500, contentHash: hash});
      await db.doc(`ledgers/${L}`).update(
        {"balances.TRY": FieldValue.increment(500)});
      const found = await problems(L);
      assert.deepEqual(found.map((p) => [p.code, p.entryId]).sort(), [
        ["CHAIN_HASH_MISMATCH", b],
        ["CONFIRMATION_MISMATCH", b],
      ]);
      assert.equal(found.find((p) => p.seq !== undefined).seq, 2);
    });

  it("bozulan zincir halkası ve sonraki halka", async () => {
    const {L, b, c} = await base();
    await entryRef(L, b).update({chainHash: "0".repeat(64)});
    assert.deepEqual(
      (await problems(L)).map((p) => [p.code, p.entryId, p.seq]),
      [["CHAIN_HASH_MISMATCH", b, 2], ["CHAIN_HASH_MISMATCH", c, 3]]);
  });

  it("son halka bozulursa defter başı da tutmaz", async () => {
    const {L, c} = await base();
    await entryRef(L, c).update({chainHash: "0".repeat(64)});
    assert.deepEqual(await codes(L),
      ["CHAIN_HASH_MISMATCH", "HEAD_CHAIN_MISMATCH"]);
  });

  it("sırada boşluk", async () => {
    const {L, c} = await base();
    await entryRef(L, c).update({confirmedSeq: 5});
    const found = await problems(L);
    assert.deepEqual(found, [
      {code: "SEQ_GAP", ledgerId: L, seq: 3, seqTo: 4},
      {code: "HEAD_SEQ_MISMATCH", ledgerId: L, expected: 5, actual: 3},
    ]);
  });

  it("aynı sıra iki kez", async () => {
    const {L, c} = await base();
    await entryRef(L, c).update({confirmedSeq: 2});
    const found = await problems(L);
    assert.deepEqual(found.map((p) => p.code).sort(),
      ["CHAIN_HASH_MISMATCH", "HEAD_SEQ_MISMATCH", "SEQ_DUPLICATE"]);
    assert.equal(found.find((p) => p.code === "SEQ_DUPLICATE").seq, 2);
  });

  it("onaylı kayıtta sıra yok, onaysız kayıtta sıra var", async () => {
    const {L, c, p} = await base();
    await entryRef(L, c).update({confirmedSeq: null});
    await entryRef(L, p).update({confirmedSeq: 9});
    const found = (await problems(L)).map((x) => [x.code, x.entryId])
      .sort((x, y) => x[0].localeCompare(y[0]));
    assert.deepEqual(found, [
      ["HEAD_SEQ_MISMATCH", undefined],
      ["SEQ_MISSING", c],
      ["SEQ_ON_UNCONFIRMED", p],
    ]);
  });

  it("defter başı uyuşmaz", async () => {
    const {L} = await base();
    await db.doc(`ledgers/${L}`).update({"head.seq": 4});
    assert.deepEqual(await problems(L), [{code: "HEAD_SEQ_MISMATCH",
      ledgerId: L, expected: 3, actual: 4}]);
    await db.doc(`ledgers/${L}`).update({"head.seq": 3, "head.chainHash": "x"});
    assert.deepEqual(await problems(L),
      [{code: "HEAD_CHAIN_MISMATCH", ledgerId: L, seq: 3}]);
  });

  it("boşa düşen reversedBy ve reversalPendingId", async () => {
    const {L, a, b} = await base();
    await entryRef(L, a).update({reversedBy: "yok"});
    await entryRef(L, b).update({reversalPendingId: "yok"});
    assert.deepEqual((await problems(L)).map((p) =>
      [p.code, p.entryId, p.relatedEntryId]).sort(), [
      ["REVERSAL_PENDING_DANGLING", b, "yok"],
      ["REVERSED_BY_DANGLING", a, "yok"],
    ]);
  });

  it("ters kayıt bağı tek taraflı kalırsa", async () => {
    const {L, a, b} = await base();
    const r = await reverse(L, "ali", a);
    const pending = await reverse(L, "ayse", b);
    await clean(L, "ters kayıtlar");
    await entryRef(L, a).update({reversedBy: null});
    await entryRef(L, b).update({reversalPendingId: null});
    assert.deepEqual((await problems(L)).map((p) =>
      [p.code, p.entryId, p.relatedEntryId, p.field]).sort(), [
      ["REVERSAL_LINK_MISMATCH", pending.reversalId, b, "reversalPendingId"],
      ["REVERSAL_LINK_MISMATCH", r.reversalId, a, "reversedBy"],
    ].sort());
  });

  it("ters kaydın tutarı düzeltilen kayıtla uyuşmaz", async () => {
    const {L, a} = await base();
    const r = await reverse(L, "ali", a);
    await entryRef(L, r.reversalId).update({linkedEntryId: "yok"});
    assert.ok((await codes(L)).includes("LINK_TARGET_MISSING"));
    await entryRef(L, r.reversalId).update({linkedEntryId: a});
    await entryRef(L, a).update({amountMinor: 1});
    assert.ok((await codes(L)).includes("REVERSAL_CONTENT_MISMATCH"));
  });

  it("yanlış bekleyen taraf ve sahte onay", async () => {
    const {L, p} = await base();
    await entryRef(L, p).update({awaitingSide: "a"});
    assert.deepEqual(await problems(L), [{code: "AWAITING_SIDE_MISMATCH",
      ledgerId: L, entryId: p, expected: "b", actual: "a"}]);
    // Bakiyeye ve zincire işlenmeden "onaylandı" yapılan kayıt.
    await entryRef(L, p).update({state: "confirmed", awaitingSide: null});
    const found = await codes(L);
    for (const code of ["BALANCE_MISMATCH", "CONFIRMATION_MISMATCH",
      "PENDING_COUNT_MISMATCH", "SEQ_MISSING"]) {
      assert.ok(found.includes(code), code);
    }
  });

  it("bozuk kayıt ve defter hata fırlatmaz, bildirilir", async () => {
    const {L, b} = await base();
    await entryRef(L, b).update({description: FieldValue.delete()});
    assert.deepEqual(await problems(L), [{code: "ENTRY_MALFORMED",
      ledgerId: L, entryId: b, field: "description"}]);

    const found = auditLedger({id: "x", data: {head: 5}},
      [{id: "e", data: {state: "confirmed", confirmedSeq: "1"}}]);
    assert.deepEqual(found.map((p) => [p.code, p.field ?? p.entryId]).sort(), [
      ["CONFIRMATION_MISMATCH", "e"],
      ["ENTRY_MALFORMED", "kind"],
      ["LEDGER_MALFORMED", "balances"],
      ["LEDGER_MALFORMED", "head"],
      ["LEDGER_MALFORMED", "pendingCount"],
      ["SEQ_MISSING", "e"],
    ]);
  });

  it("defter belgesi silinmiş ama kayıtları kalmış", async () => {
    const {L} = await base();
    await db.doc(`ledgers/${L}`).delete();
    assert.deepEqual(await problems(L),
      [{code: "LEDGER_MISSING", ledgerId: L}]);
  });

  it("sorunlarda kişisel veri yok; denetim hiçbir şey yazmaz", async () => {
    const {L, a, b} = await base();
    await entryRef(L, a).update({reversedBy: "yok"});
    await entryRef(L, b).update({amountMinor: 2500});
    await db.doc(`ledgers/${L}`).update({"balances.TRY": 1});
    const paths = async () => {
      const docs = (await db.collection(`ledgers/${L}/entries`).get()).docs;
      const ledger = await ledgerDoc(L);
      return [ledger, ...docs].map((d) =>
        `${d.ref.path}@${d.updateTime.toMillis()}`).sort();
    };
    const before = await paths();
    const found = await problems(L);
    assert.deepEqual(await paths(), before);
    const text = JSON.stringify(found);
    for (const secret of ["Yemek", "Ali Veli", "Ayşe", "@example.com"]) {
      assert.equal(text.includes(secret), false, secret);
    }
  });
});
