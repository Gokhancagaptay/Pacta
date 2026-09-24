// firestore.rules testleri. Çalıştırma: npm run emulator:test (Java 11+ gerekir).
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
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
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

describe("debts oluşturma", () => {
  it("geçerli bekleyen kayıt ve not oluşturulur", async () => {
    await assertSucceeds(addDoc(collection(ali(), "debts"), newDebt()));
    await assertSucceeds(
      addDoc(
        collection(ali(), "debts"),
        newDebt({
          status: "note",
          borcluId: "note_user_1",
          visibleto: ["ali"],
          isShared: false,
          requiresApproval: false,
        }),
      ),
    );
  });

  it("onaylı kayıt doğrudan oluşturulamaz", async () => {
    await assertFails(
      addDoc(collection(ali(), "debts"), newDebt({status: "approved"})),
    );
  });

  it("başkası adına veya kayıtsız kişiye kayıt açılamaz", async () => {
    await assertFails(addDoc(collection(mallory(), "debts"), newDebt()));
    await assertFails(
      addDoc(
        collection(ali(), "debts"),
        newDebt({borcluId: "ghost", visibleto: ["ali", "ghost"]}),
      ),
    );
    await assertFails(
      addDoc(collection(ali(), "debts"), newDebt({visibleto: ["ali"]})),
    );
  });

  it("geçersiz tutar ve fazladan alan reddedilir", async () => {
    await assertFails(addDoc(collection(ali(), "debts"), newDebt({miktar: 0})));
    await assertFails(
      addDoc(collection(ali(), "debts"), newDebt({miktar: -10})),
    );
    await assertFails(addDoc(collection(ali(), "debts"), newDebt({extra: 1})));
  });
});

describe("debts durum geçişleri", () => {
  it("kayıt sahibi kendi talebini onaylayamaz", async () => {
    await assertFails(
      updateDoc(doc(ali(), "debts/pending1"), {
        status: "approved",
        updatedById: "ali",
      }),
    );
  });

  it("karşı taraf onaylar; onaylarken tutarı değiştiremez", async () => {
    await assertFails(
      updateDoc(doc(ayse(), "debts/pending1"), {
        status: "approved",
        updatedById: "ayse",
        miktar: 1,
      }),
    );
    await assertSucceeds(
      updateDoc(doc(ayse(), "debts/pending1"), {
        status: "approved",
        updatedById: "ayse",
      }),
    );
  });

  it("taraf olmayan onaylayamaz", async () => {
    await assertFails(
      updateDoc(doc(mallory(), "debts/pending1"), {
        status: "approved",
        updatedById: "mallory",
      }),
    );
  });

  it("onaylı kayıt için silme talebi açılır, doğrudan silinemez", async () => {
    await assertFails(deleteDoc(doc(ali(), "debts/approved1")));
    await assertSucceeds(
      updateDoc(doc(ayse(), "debts/approved1"), {
        status: "pending_deletion",
        deletion_requester_id: "ayse",
      }),
    );
  });

  it("silme talebini talep eden onaylayamaz veya geri alamaz", async () => {
    await assertFails(deleteDoc(doc(ali(), "debts/deletion1")));
    await assertFails(
      updateDoc(doc(ali(), "debts/deletion1"), {
        status: "approved",
        deletion_requester_id: deleteField(),
      }),
    );
  });

  it("karşı taraf silme talebini reddeder veya onaylar", async () => {
    await assertSucceeds(
      updateDoc(doc(ayse(), "debts/deletion1"), {
        status: "approved",
        deletion_requester_id: deleteField(),
      }),
    );
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), "debts/deletion1"),
        newDebt({status: "pending_deletion", deletion_requester_id: "ali"}),
      );
    });
    await assertSucceeds(deleteDoc(doc(ayse(), "debts/deletion1")));
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
