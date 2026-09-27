import {
  DocumentReference,
  FieldValue,
  Transaction,
} from "firebase-admin/firestore";
import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {admin, db} from "../common/firebase";
import {OPTS, requireRecentLogin} from "./callable";
import {Ledger, Side, otherSide, sideOf} from "./model";
import {Notice, notificationData, pushOnly} from "./notify";

// Hesap silme (Apple 5.1.1(v), Google Play hesap silme şartı).
//
// Silinen: kişinin profili, bildirimleri, gelen kutusu, Pacta kodu,
// sayaçları, bekleyen bildirimleri, özel defterleri ve giriş hesabı.
// Kalan: ortak defterler karşı tarafın da kaydıdır; onun nüshası olarak
// saklanır (plan §8.1). Silinen tarafın adı "Silinmiş kullanıcı" olur,
// e-postası kaldırılır, defter kapanır (yeni kayıt eklenemez). Kayıtlarda
// kişi kimliği (uid) kalır: bu takma addır, anonim değildir. Açık kayıtlar
// kapatılır: kişinin kendi önerileri geri çekilir, karşı tarafın açık
// kayıtları reddedilir. Karşı taraf da hesabını silmişse defter tamamen
// silinir (saklanacak kimse kalmaz).
//
// Silme başında deletedAccounts/{uid} işareti yazılır ve oturumlar iptal
// edilir: kişinin eski belirteci (~1 saat geçerli) komut çalıştıramaz,
// kimse onunla yeni defter açamaz, istemci profili yeniden oluşturamaz.

export const DELETED_NAME = "Silinmiş kullanıcı";

/** Silme için girişin en fazla bu kadar yeni olması gerekir (saniye). */
export const REAUTH_WINDOW_SECONDS = 5 * 60;

/** Testlerde saat değiştirilebilsin diye. */
export const accountClock = {now: (): Date => new Date()};

type CloseResult = {closed: boolean; purge: boolean; notice: Notice | null};

/**
 * Karşı tarafa bildirimi aynı transaction'da, sabit kimlikle yazar: silme
 * yarıda kalıp tekrar çalışsa da bildirim kaybolmaz ve çoğalmaz.
 * @param {Transaction} tx Transaction.
 * @param {Notice} n Bildirim.
 */
function writeNotice(tx: Transaction, n: Notice) {
  tx.set(
    db.collection("users").doc(n.uid)
      .collection("notifications").doc(`accountDeleted_${n.ledgerId}`),
    notificationData(n)
  );
}

/**
 * Ortak defteri silinen kişi adına kapatır. Karşı taraf da silinmişse
 * defterin tamamen silinmesi gerektiğini bildirir. Tekrar çalıştırılırsa
 * değişiklik yapmaz.
 * @param {DocumentReference} ref Defter.
 * @param {string} uid Silinen kişi.
 * @return {Promise<CloseResult>} Sonuç.
 */
async function closeSharedLedger(
  ref: DocumentReference,
  uid: string
): Promise<CloseResult> {
  const nothing: CloseResult = {closed: false, purge: false, notice: null};
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return nothing;
    const ledger = snap.data() as Ledger;
    const side = sideOf(ledger, uid);
    if (!side) return nothing;
    const other: Side = otherSide(side);
    // İki taraf da silindiyse defter kimse için saklanmaz.
    if (ledger.sides[other].deleted) {
      return {closed: false, purge: true, notice: null};
    }
    if (ledger.sides[side].deleted) return nothing;

    // Transaction'da tüm okumalar yazmalardan önce yapılır.
    const open = await tx.get(
      ref.collection("entries").where("awaitingSide", "in", ["a", "b"])
    );
    const otherUid = ledger.sides[other].uid;
    // Karşı tarafın hesabı da silinmekteyse ona bildirim yazılmaz.
    const otherExists = otherUid ?
      (await tx.get(db.collection("users").doc(otherUid))).exists :
      false;
    const now = FieldValue.serverTimestamp();
    for (const doc of open.docs) {
      const e = doc.data();
      if (e.state !== "pending" && e.state !== "disputed") continue;
      const mine = e.proposedBy === side;
      tx.update(doc.ref, mine ? {
        state: "cancelled",
        awaitingSide: null,
        updatedAt: now,
      } : {
        state: "rejected",
        awaitingSide: null,
        rejection: {byUid: uid, reason: "accountDeleted", note: "", at: now},
        updatedAt: now,
      });
      if (e.kind === "reversal" && e.linkedEntryId) {
        tx.update(ref.collection("entries").doc(e.linkedEntryId), {
          reversalPendingId: null,
          updatedAt: now,
        });
      }
      tx.set(ref.collection("events").doc(), {
        type: mine ? "cancelled" : "rejected",
        entryId: doc.id,
        version: e.version,
        contentHash: e.contentHash,
        actorUid: uid,
        reason: "accountDeleted",
        memberUids: ledger.memberUids,
        at: now,
      });
      if (otherUid) {
        tx.delete(db.collection("users").doc(otherUid)
          .collection("inbox").doc(doc.id));
      }
    }

    tx.update(ref, {
      "status": "closed",
      "closedAt": now,
      "updatedAt": now,
      "pendingCount": 0,
      // Vadeler artık kapatılamaz; listelerde sonsuza dek görünmesin.
      "dueItems": [],
      "dueDates": [],
      [`sides.${side}.displayName`]: DELETED_NAME,
      [`sides.${side}.email`]: null,
      [`sides.${side}.deleted`]: true,
      [`reminders.${side}`]: FieldValue.delete(),
    });

    if (!otherUid) return {closed: true, purge: false, notice: null};
    const notice: Notice = {
      uid: otherUid,
      setting: "statusChanges",
      type: "accountDeleted",
      title: "Hesap silindi",
      message: `${ledger.sides[side].displayName} Pacta hesabını sildi. ` +
        "Ortak geçmişiniz sizde saklanıyor; bu kişiye yeni kayıt eklenemez.",
      ledgerId: ref.id,
      entryId: null,
    };
    if (!otherExists) return {closed: true, purge: false, notice: null};
    writeNotice(tx, notice);
    return {closed: true, purge: false, notice};
  });
}

/**
 * Bir sorgunun tüm belgelerini 400'lük parçalar hâlinde siler.
 * @param {FirebaseFirestore.Query} query Sorgu.
 */
async function deleteQuery(query: FirebaseFirestore.Query): Promise<void> {
  for (;;) {
    const snap = await query.limit(400).get();
    if (snap.empty) return;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

/**
 * Kişinin tüm defterlerini ele alır: özel defterleri siler, ortak defterleri
 * kapatır (karşı taraf da silinmişse siler), kapanan deftere ait bekleyen
 * bildirimleri kaldırır.
 * @param {string} uid Silinen kişi.
 * @return {Promise<object>} Sayılar ve karşı taraflara gidecek push'lar.
 */
async function settleLedgers(uid: string) {
  const ledgers = await db.collection("ledgers")
    .where("memberUids", "array-contains", uid).get();
  const notices: Notice[] = [];
  let closedLedgers = 0;
  let deletedLedgers = 0;
  for (const doc of ledgers.docs) {
    const ledger = doc.data() as Ledger;
    if (ledger.mode === "private") {
      if (ledger.sides.a.uid === uid) {
        await db.recursiveDelete(doc.ref);
        deletedLedgers++;
      }
      continue;
    }
    const result = await closeSharedLedger(doc.ref, uid);
    if (result.purge) {
      await db.recursiveDelete(doc.ref);
      deletedLedgers++;
    }
    if (result.closed) closedLedgers++;
    if (result.notice) notices.push(result.notice);
    // Silinen kişinin gece gönderdiği, sabaha kalan hatırlatma vb.
    if (result.closed || result.purge) {
      await deleteQuery(db.collection("pushQueue")
        .where("data.ledgerId", "==", doc.id));
    }
  }
  return {closedLedgers, deletedLedgers, notices};
}

/**
 * Hesabın verilerini siler; ortak defterlerdeki geçmiş karşı taraf için
 * takma adla ("Silinmiş kullanıcı") kalır. Yarıda kalırsa tekrar
 * çağrılabilir.
 * @param {string} uid Silinecek kişi.
 * @return {Promise<object>} Özet.
 */
export async function deleteAccountData(
  uid: string
): Promise<{closedLedgers: number; deletedLedgers: number}> {
  const {closedLedgers, deletedLedgers, notices} = await settleLedgers(uid);

  const userRef = db.collection("users").doc(uid);
  const code = (await userRef.get()).get("pactaCode") as string | undefined;
  if (code) {
    const codeRef = db.collection("codes").doc(code);
    const owner = (await codeRef.get()).get("uid");
    if (owner === uid) await codeRef.delete();
  }
  await db.recursiveDelete(userRef);
  await db.collection("publicProfiles").doc(uid).delete();
  const counters = ["reminders", "codes", "ledgers", "entries", "revisions"];
  await Promise.all(counters.map((k) =>
    db.collection("rateLimits").doc(`${k}_${uid}`).delete()));
  await deleteQuery(db.collection("pushQueue").where("uid", "==", uid));

  // Uygulama içi bildirimler kapatma transaction'ında yazıldı; push'lar
  // en son ve en iyi çabayla gider.
  await pushOnly(notices);
  return {closedLedgers, deletedLedgers};
}

/**
 * Oturumdaki kişinin hesabını siler. İstemci önce yeniden giriş yapar
 * (şifre ya da Google); eski oturumla silme reddedilir. Tekrar
 * çağrılabilir (silme işareti komutları engeller, bu çağrıyı değil).
 */
export const deleteAccount = onCall<unknown>(
  {...OPTS, timeoutSeconds: 300},
  async (req) => {
    const uid = requireRecentLogin(req, REAUTH_WINDOW_SECONDS,
      accountClock.now());
    await db.collection("deletedAccounts").doc(uid)
      .set({deletedAt: FieldValue.serverTimestamp()}, {merge: true});
    try {
      await admin.auth().revokeRefreshTokens(uid);
    } catch (error) {
      if ((error as {code?: string}).code !== "auth/user-not-found") {
        throw error;
      }
    }
    const summary = await deleteAccountData(uid);
    try {
      await admin.auth().deleteUser(uid);
    } catch (error) {
      if ((error as {code?: string}).code !== "auth/user-not-found") {
        throw error;
      }
    }
    // Silme sürerken açılmış olabilecek defterler için son tarama.
    const late = await settleLedgers(uid);
    await pushOnly(late.notices);
    logger.info("[account] Hesap silindi", {uid, ...summary});
    return {deleted: true, ...summary};
  }
);
