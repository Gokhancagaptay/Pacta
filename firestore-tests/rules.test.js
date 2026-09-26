// firestore.rules testleri. Çalıştırma: npm run emulator:test (Java 11+ gerekir).
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {after, before, beforeEach, describe, it} from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  addDoc,
  collection,
  collectionGroup,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} from "firebase/firestore";

let env;

const ali = () =>
  env.authenticatedContext("ali", {email: "ali@example.com"}).firestore();
const ayse = () =>
  env.authenticatedContext("ayse", {email: "ayse@example.com"}).firestore();
const mallory = () =>
  env.authenticatedContext("mallory", {email: "m@example.com"}).firestore();
const anon = () => env.unauthenticatedContext().firestore();

// Ali alacaklı, Ayşe borçlu; kaydı Ali oluşturmuş.
function newDebt(overrides = {}) {
  return {
    borcluId: "ayse",
    alacakliId: "ali",
    miktar: 150.5,
    aciklama: "Yemek",
    islemTarihi: Timestamp.now(),
    tahminiOdemeTarihi: null,
    createdAt: serverTimestamp(),
    dueReminderSent: false,
    status: "pending",
    isShared: true,
    requiresApproval: true,
    visibleto: ["ali", "ayse"],
    createdBy: "ali",
    deletion_requester_id: null,
    ...overrides,
  };
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-pacta",
    firestore: {
      rules: readFileSync(
        new URL("../firestore.rules", import.meta.url),
        "utf8",
      ),
    },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users/ali"), {
      uid: "ali",
      email: "ali@example.com",
      adSoyad: "Ali",
      telefon: "5550000000",
    });
    await setDoc(doc(db, "users/ayse"), {
      uid: "ayse",
      email: "ayse@example.com",
      adSoyad: "Ayşe",
    });
    await setDoc(doc(db, "publicProfiles/ali"), {adSoyad: "Ali"});
    await setDoc(doc(db, "debts/pending1"), newDebt());
    await setDoc(doc(db, "debts/approved1"), newDebt({status: "approved"}));
    await setDoc(
      doc(db, "debts/deletion1"),
      newDebt({status: "pending_deletion", deletion_requester_id: "ali"}),
    );
    await setDoc(doc(db, "notifications/n1"), {
      toUserId: "ayse",
      message: "Yeni Borç Bildirimi",
      isRead: false,
    });
  });
});

describe("users", () => {
  it("giriş yapmamış kullanıcı profil okuyamaz", async () => {
    await assertFails(getDoc(doc(anon(), "users/ali")));
  });

  it("kullanıcı listesi kimseye açık değil", async () => {
    await assertFails(getDocs(collection(ali(), "users")));
    await assertFails(
      getDocs(
        query(
          collection(mallory(), "users"),
          where("email", "==", "ali@example.com"),
        ),
      ),
    );
  });

  it("başkasının profili okunamaz, kendi profili okunur", async () => {
    await assertFails(getDoc(doc(mallory(), "users/ali")));
    await assertSucceeds(getDoc(doc(ali(), "users/ali")));
  });

  it("e-posta değiştirilemez, ad değiştirilebilir", async () => {
    await assertFails(
      updateDoc(doc(ali(), "users/ali"), {email: "ayse@example.com"}),
    );
    await assertSucceeds(updateDoc(doc(ali(), "users/ali"), {adSoyad: "Ali V."}));
  });

  it("eksik e-posta yalnızca giriş e-postasıyla tamamlanır", async () => {
    // Bildirim anahtarı belgeyi profilden önce oluşturmuş olabilir.
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), "users/veli"), {fcmToken: "t"}));
    const veli = env
      .authenticatedContext("veli", {email: "veli@example.com"})
      .firestore();
    await assertFails(updateDoc(doc(veli, "users/veli"),
      {email: "ali@example.com"}));
    await assertSucceeds(updateDoc(doc(veli, "users/veli"),
      {uid: "veli", email: "veli@example.com", adSoyad: "Veli"}));
    // Bir kez yazılan e-posta değişmez.
    await assertFails(updateDoc(doc(veli, "users/veli"),
      {email: "veli2@example.com"}));
  });

  it("ad en fazla 100 karakter", async () => {
    await assertFails(
      updateDoc(doc(ali(), "users/ali"), {adSoyad: "x".repeat(101)}));
    await assertSucceeds(
      updateDoc(doc(ali(), "users/ali"), {adSoyad: "x".repeat(100)}));
  });

  it("profil yalnızca giriş e-postasıyla oluşturulur", async () => {
    const veli = env
      .authenticatedContext("veli", {email: "veli@example.com"})
      .firestore();
    await assertFails(
      setDoc(doc(veli, "users/veli"), {uid: "veli", email: "ali@example.com"}),
    );
    await assertSucceeds(
      setDoc(doc(veli, "users/veli"), {uid: "veli", email: "veli@example.com"}),
    );
  });
});

describe("publicProfiles", () => {
  it("giriş yapan okur, giriş yapmayan okuyamaz", async () => {
    await assertSucceeds(getDoc(doc(mallory(), "publicProfiles/ali")));
    await assertFails(getDoc(doc(anon(), "publicProfiles/ali")));
  });

  it("yalnızca sahibi ve yalnızca ad alanını yazar", async () => {
    await assertSucceeds(
      setDoc(doc(ali(), "publicProfiles/ali"), {adSoyad: "Ali Veli"}),
    );
    await assertFails(
      setDoc(doc(ali(), "publicProfiles/ali"), {adSoyad: "Ali", email: "x"}),
    );
    await assertFails(
      setDoc(doc(mallory(), "publicProfiles/ali"), {adSoyad: "Sahte"}),
    );
  });
});

describe("debts okuma", () => {
  it("taraf olmayan okuyamaz, taraf okur", async () => {
    await assertFails(getDoc(doc(mallory(), "debts/pending1")));
    await assertSucceeds(getDoc(doc(ayse(), "debts/pending1")));
  });

  it("silinmiş kayıt izin hatası değil 'yok' döner", async () => {
    const snap = await assertSucceeds(getDoc(doc(ayse(), "debts/silinmis")));
    assert.equal(snap.exists(), false);
    await assertFails(getDoc(doc(anon(), "debts/silinmis")));
  });

  it("liste yalnızca visibleto filtresiyle", async () => {
    await assertSucceeds(
      getDocs(
        query(
          collection(ayse(), "debts"),
          where("visibleto", "array-contains", "ayse"),
        ),
      ),
    );
    await assertFails(getDocs(collection(ayse(), "debts")));
  });
});

describe("debts (v1 arşivi)", () => {
  it("kimse yeni kayıt açamaz, güncelleyemez, silemez", async () => {
    await assertFails(setDoc(doc(ali(), "debts/yeni"), newDebt()));
    await assertFails(
      addDoc(collection(ali(), "debts"), newDebt({status: "note",
        visibleto: ["ali"], isShared: false, requiresApproval: false})));
    await assertFails(updateDoc(doc(ayse(), "debts/pending1"),
      {status: "approved", updatedById: "ayse"}));
    await assertFails(deleteDoc(doc(ayse(), "debts/deletion1")));
  });
});

describe("v2 defterler", () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      const members = {memberUids: ["ali", "ayse"]};
      await setDoc(doc(db, "ledgers/p_ali_ayse"), {
        ...members,
        mode: "shared",
        balances: {TRY: 50000},
        lastEntryAt: Timestamp.now(),
      });
      await setDoc(doc(db, "ledgers/p_ali_ayse/entries/e1"), {
        ...members, state: "pending", amountMinor: 50000,
      });
      await setDoc(doc(db, "ledgers/p_ali_ayse/entries/e1/revisions/1"), {
        ...members, version: 1,
      });
      await setDoc(doc(db, "ledgers/p_ali_ayse/events/ev1"), {
        ...members, type: "created",
      });
      await setDoc(doc(db, "users/ayse/inbox/e1"), {type: "confirmEntry"});
      await setDoc(doc(db, "users/ayse/notifications/n1"), {
        message: "Onayınız bekleniyor", isRead: false,
      });
    });
  });

  it("taraflar defteri okur ve listeler, yabancı okuyamaz", async () => {
    await assertSucceeds(getDoc(doc(ayse(), "ledgers/p_ali_ayse")));
    await assertSucceeds(getDocs(query(
      collection(ali(), "ledgers"),
      where("memberUids", "array-contains", "ali"))));
    await assertFails(getDoc(doc(mallory(), "ledgers/p_ali_ayse")));
    await assertFails(getDocs(collection(mallory(), "ledgers")));
    await assertFails(getDoc(doc(anon(), "ledgers/p_ali_ayse")));
  });

  it("olmayan defter izin hatası değil 'yok' döner", async () => {
    const snap = await assertSucceeds(getDoc(doc(mallory(), "ledgers/p_x_y")));
    assert.equal(snap.exists(), false);
  });

  it("kayıt, sürüm ve olayları yalnızca taraflar okur", async () => {
    for (const path of [
      "ledgers/p_ali_ayse/entries/e1",
      "ledgers/p_ali_ayse/entries/e1/revisions/1",
      "ledgers/p_ali_ayse/events/ev1",
    ]) {
      await assertSucceeds(getDoc(doc(ali(), path)));
      await assertFails(getDoc(doc(mallory(), path)));
    }
  });

  it("istemci deftere, kayda ve bakiyeye yazamaz", async () => {
    await assertFails(updateDoc(doc(ali(), "ledgers/p_ali_ayse"),
      {"balances.TRY": 999999}));
    await assertFails(setDoc(doc(ali(), "ledgers/p_ali_yeni"),
      {memberUids: ["ali"]}));
    await assertFails(updateDoc(doc(ayse(), "ledgers/p_ali_ayse/entries/e1"),
      {state: "confirmed"}));
    await assertFails(setDoc(doc(ali(), "ledgers/p_ali_ayse/entries/e2"),
      {memberUids: ["ali", "ayse"], state: "confirmed"}));
    await assertFails(deleteDoc(doc(ali(), "ledgers/p_ali_ayse/events/ev1")));
  });

  it("gelen kutusu ve bildirimler yalnızca sahibine açık", async () => {
    await assertSucceeds(getDoc(doc(ayse(), "users/ayse/inbox/e1")));
    await assertFails(getDoc(doc(ali(), "users/ayse/inbox/e1")));
    await assertFails(setDoc(doc(ayse(), "users/ayse/inbox/e9"), {x: 1}));
    await assertSucceeds(updateDoc(doc(ayse(), "users/ayse/notifications/n1"),
      {isRead: true}));
    await assertFails(updateDoc(doc(ayse(), "users/ayse/notifications/n1"),
      {message: "Değişti"}));
    await assertFails(setDoc(doc(ali(), "users/ayse/notifications/n2"),
      {message: "Sahte", isRead: false}));
  });

  it("tüm defterlerdeki kayıtlar yalnızca üyelik filtresiyle listelenir",
    async () => {
      const recent = (db, uid) => getDocs(query(
        collectionGroup(db, "entries"),
        where("memberUids", "array-contains", uid),
        orderBy("updatedAt", "desc")));
      await assertSucceeds(recent(ali(), "ali"));
      await assertFails(recent(mallory(), "ali"));
      await assertFails(getDocs(collectionGroup(mallory(), "entries")));
    });

  it("hatırlatma sessize alma yalnızca sahibinin profilinde", async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), "users/ayse"),
        {email: "ayse@example.com", adSoyad: "Ayşe"}));
    await assertSucceeds(updateDoc(doc(ayse(), "users/ayse"),
      {"reminderMutes.p_ali_ayse": true}));
    await assertFails(updateDoc(doc(ali(), "users/ayse"),
      {"reminderMutes.p_ali_ayse": false}));
  });

  it("Pacta kodu istemciden yazılamaz, kod tablosu kapalı", async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), "users/ali"),
        {email: "ali@example.com", pactaCode: "K7Q3XM"}));
    await assertFails(updateDoc(doc(ali(), "users/ali"),
      {pactaCode: "AAAAAA"}));
    await assertSucceeds(updateDoc(doc(ali(), "users/ali"),
      {"favoriteLedgers.p_ali_ayse": true}));
    await assertFails(setDoc(doc(ayse(), "users/ayse"),
      {email: "ayse@example.com", pactaCode: "K7Q3XM"}));
    await assertFails(getDoc(doc(ali(), "codes/K7Q3XM")));
    await assertFails(setDoc(doc(ali(), "codes/AAAAAA"), {uid: "ali"}));
  });

  it("hatırlatma kuyruğu ve sınırları istemciye kapalı", async () => {
    await assertFails(getDocs(collection(ali(), "pushQueue")));
    await assertFails(getDoc(doc(ali(), "rateLimits/reminders_ali")));
    await assertFails(setDoc(doc(ali(), "rateLimits/reminders_ali"),
      {day: "2026-09-25", count: 0}));
  });
});

describe("notifications", () => {
  it("istemci bildirim oluşturamaz", async () => {
    await assertFails(
      addDoc(collection(ali(), "notifications"), {
        toUserId: "ayse",
        message: "Sahte bildirim",
        isRead: false,
      }),
    );
  });

  it("yalnızca alıcı okur", async () => {
    await assertSucceeds(getDoc(doc(ayse(), "notifications/n1")));
    await assertSucceeds(
      getDocs(
        query(
          collection(ayse(), "notifications"),
          where("toUserId", "==", "ayse"),
        ),
      ),
    );
    await assertFails(getDoc(doc(ali(), "notifications/n1")));
  });

  it("alıcı yalnızca okundu bilgisini değiştirir", async () => {
    await assertSucceeds(
      updateDoc(doc(ayse(), "notifications/n1"), {isRead: true}),
    );
    await assertFails(
      updateDoc(doc(ayse(), "notifications/n1"), {message: "Değişti"}),
    );
  });
});
