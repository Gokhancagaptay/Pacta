import {DocumentReference, FieldValue} from "firebase-admin/firestore";
import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {admin, db} from "../common/firebase";
import {OPTS, requireRecentLogin} from "./callable";
import {Ledger, Side, otherSide, sideOf} from "./model";
import {Notice, deliver} from "./notify";

// Hesap silme (Apple 5.1.1(v), Google Play hesap silme şartı).
//
// Silinen: kişinin profili, bildirimleri, gelen kutusu, Pacta kodu,
// sayaçları, özel defterleri ve giriş hesabı.
// Kalan: ortak defterler karşı tarafın da kaydıdır; onaylı geçmiş onun
// nüshası olarak saklanır (plan §8.1). Silinen tarafın adı "Silinmiş
// kullanıcı" olur, e-postası kaldırılır, defter kapanır (yeni kayıt
// eklenemez). Açık kayıtlar kapatılır: kişinin kendi önerileri geri
// çekilir, onun onayını bekleyenler reddedilir.

export const DELETED_NAME = "Silinmiş kullanıcı";

/** Silme için girişin en fazla bu kadar yeni olması gerekir (saniye). */
export const REAUTH_WINDOW_SECONDS = 5 * 60;

/** Testlerde saat değiştirilebilsin diye. */
export const accountClock = {now: (): Date => new Date()};

/**
 * Ortak defteri silinen kişi adına kapatır; karşı tarafa bildirim döner.
 * Tekrar çalıştırılırsa (yarıda kalan silme) değişiklik yapmaz.
 * @param {DocumentReference} ref Defter.
 * @param {string} uid Silinen kişi.
 * @return {Promise<Notice | null>} Karşı tarafa gidecek bildirim.
 */
async function closeSharedLedger(
  ref: DocumentReference,
  uid: string
): Promise<Notice | null> {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    const ledger = snap.data() as Ledger;
    const side = sideOf(ledger, uid);
    if (!side || ledger.sides[side].deleted) return null;
    const other: Side = otherSide(side);
    const open = await tx.get(
      ref.collection("entries").where("awaitingSide", "in", ["a", "b"])
    );

    const now = FieldValue.serverTimestamp();
    const otherUid = ledger.sides[other].uid;
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
      [`sides.${side}.displayName`]: DELETED_NAME,
      [`sides.${side}.email`]: null,
      [`sides.${side}.deleted`]: true,
      [`reminders.${side}`]: FieldValue.delete(),
    });

    if (!otherUid) return null;
    const name = ledger.sides[side].displayName;
    return {
      uid: otherUid,
      setting: "statusChanges",
      type: "accountDeleted",
      title: "Hesap silindi",
      message: `${name} Pacta hesabını sildi. Ortak geçmişiniz sizde ` +
        "saklanıyor; bu kişiye yeni kayıt eklenemez.",
      ledgerId: ref.id,
      entryId: null,
    };
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
 * Hesabı ve kişisel verileri siler; ortak defterlerdeki geçmiş karşı taraf
 * için anonim olarak kalır. Yarıda kalırsa tekrar çağrılabilir.
 * @param {string} uid Silinecek kişi.
 * @return {Promise<object>} Özet.
 */
export async function deleteAccountData(
  uid: string
): Promise<{closedLedgers: number; deletedLedgers: number}> {
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
    const notice = await closeSharedLedger(doc.ref, uid);
    if (notice) {
      notices.push(notice);
      closedLedgers++;
    }
  }

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

  // Karşı taraflara haber verilir (silinen kişiye değil).
  await deliver(notices);
  return {closedLedgers, deletedLedgers};
}

/**
 * Oturumdaki kişinin hesabını siler. İstemci önce yeniden giriş yapar
 * (şifre ya da Google); eski oturumla silme reddedilir.
 */
export const deleteAccount = onCall<unknown>(OPTS, async (req) => {
  const uid = requireRecentLogin(req, REAUTH_WINDOW_SECONDS,
    accountClock.now());
  const summary = await deleteAccountData(uid);
  try {
    await admin.auth().deleteUser(uid);
  } catch (error) {
    if ((error as {code?: string}).code !== "auth/user-not-found") throw error;
  }
  logger.info("[account] Hesap silindi", {uid, ...summary});
  return {deleted: true, ...summary};
});
