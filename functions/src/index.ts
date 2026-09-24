// functions/src/index.ts
import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

const db = admin.firestore();
const REGION = "europe-west1";

type DebtData = {
  alacakliId: string;
  borcluId: string;
  miktar: number;
  status: string;
  createdBy?: string;
  updatedById?: string;
  "deletion_requester_id"?: string;
  dueReminderSent?: boolean;
};

const amountFormat = new Intl.NumberFormat("tr-TR", {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

/**
 * Tutarı "1.234,50₺" biçiminde yazar.
 * @param {number} amount Tutar.
 * @return {string} Biçimli tutar.
 */
function formatAmount(amount: number): string {
  return `${amountFormat.format(amount)}₺`;
}

/**
 * Kullanıcının görünen adını döndürür.
 * @param {string} uid Kullanıcı ID'si.
 * @return {Promise<string>} Ad soyad, yoksa e-posta, yoksa "Bilinmeyen".
 */
async function getDisplayName(uid: string): Promise<string> {
  const snap = await db.collection("users").doc(uid).get();
  return snap.get("adSoyad") || snap.get("email") || "Bilinmeyen";
}

/**
 * Borcun diğer tarafını döndürür.
 * @param {DebtData} debt Borç kaydı.
 * @param {string} uid Taraflardan biri.
 * @return {string} Diğer tarafın ID'si.
 */
function otherParty(debt: DebtData, uid: string): string {
  return uid === debt.alacakliId ? debt.borcluId : debt.alacakliId;
}

/**
 * Kullanıcıya FCM üzerinden push bildirimi gönderir.
 * @param {string} toUserId Alıcı kullanıcı ID'si.
 * @param {string} title Bildirim başlığı.
 * @param {string} body Bildirim içeriği.
 * @param {object} data Bildirimle gönderilecek ek veri.
 */
async function sendPushNotification(
  toUserId: string,
  title: string,
  body: string,
  data: {[key: string]: string}
) {
  try {
    const userDoc = await db.collection("users").doc(toUserId).get();
    const fcmToken = userDoc.get("fcmToken") as string | undefined;

    if (!fcmToken) {
      logger.warn(`[push] FCM token yok, atlandı: ${toUserId}`);
      return;
    }
    await admin.messaging().send({
      token: fcmToken,
      notification: {title, body},
      data,
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            contentAvailable: true,
          },
        },
      },
    });
    logger.info(`[push] Gönderildi: ${toUserId}`);
  } catch (error) {
    const err = error as {message?: string; code?: string; stack?: string};
    logger.error(`[push] Gönderilemedi: ${toUserId}`, {
      errorMessage: err.message,
      errorCode: err.code,
      errorStack: err.stack,
    });
  }
}

type NotificationInput = {
  toUserId: string;
  type: string;
  title: string;
  message: string;
  debtId: string;
  debt: DebtData;
  createdById: string;
};

/**
 * Uygulama içi bildirimi yazar ve push gönderir.
 * Bildirimleri yalnızca Functions yazar; istemci yazamaz (firestore.rules).
 * @param {NotificationInput} input Bildirim bilgileri.
 */
async function notify(input: NotificationInput): Promise<void> {
  await db.collection("notifications").add({
    toUserId: input.toUserId,
    type: input.type,
    relatedDebtId: input.debtId,
    title: input.title,
    message: input.message,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdById: input.createdById,
    creditorId: input.debt.alacakliId,
    debtorId: input.debt.borcluId,
    amount: input.debt.miktar,
  });
  await sendPushNotification(input.toUserId, input.title, input.message, {
    type: input.type,
    relatedDebtId: input.debtId,
  });
}

export const onDebtCreate = onDocumentCreated(
  {
    document: "debts/{debtId}",
    region: REGION,
  },
  async (event) => {
    const debt = event.data?.data() as DebtData | undefined;
    if (!debt || debt.status !== "pending" || !debt.createdBy) return;

    const creatorName = await getDisplayName(debt.createdBy);
    const amount = formatAmount(debt.miktar);
    const creatorIsCreditor = debt.createdBy === debt.alacakliId;

    await notify({
      toUserId: otherParty(debt, debt.createdBy),
      type: "approval_request",
      title: creatorIsCreditor ? "Yeni Borç Bildirimi" : "Yeni Alacak Talebi",
      message: creatorIsCreditor ?
        `${creatorName} size ${amount} tutarında bir borç bildiriminde ` +
          "bulundu." :
        `${creatorName} sizden ${amount} tutarında bir talepte bulundu.`,
      debtId: event.params.debtId,
      debt,
      createdById: debt.createdBy,
    });
  }
);

export const onDebtStatusUpdate = onDocumentUpdated(
  {
    document: "debts/{debtId}",
    region: REGION,
  },
  async (event) => {
    const before = event.data?.before.data() as DebtData | undefined;
    const after = event.data?.after.data() as DebtData | undefined;
    if (!before || !after || before.status === after.status) return;

    const debtId = event.params.debtId;
    const amount = formatAmount(after.miktar);

    // Onay / ret: karşı taraf pending kaydı yanıtladı.
    if (
      before.status === "pending" &&
      (after.status === "approved" || after.status === "rejected")
    ) {
      const actorId = after.updatedById;
      if (!actorId) return;
      const approved = after.status === "approved";
      const subject = actorId === after.alacakliId ?
        "alacak talebiniz" :
        "borç bildiriminiz";
      const actorName = await getDisplayName(actorId);
      await notify({
        toUserId: otherParty(after, actorId),
        type: approved ? "request_approved" : "request_rejected",
        title: approved ? "Talep Onaylandı" : "Talep Reddedildi",
        message: `${amount} tutarındaki ${subject} ${actorName} ` +
          `tarafından ${approved ? "onaylandı" : "reddedildi"}.`,
        debtId,
        debt: after,
        createdById: actorId,
      });
      return;
    }

    // Silme talebi: onaylı kaydın silinmesi istendi.
    if (before.status === "approved" && after.status === "pending_deletion") {
      const requesterId = after["deletion_requester_id"];
      if (!requesterId) return;
      const requesterName = await getDisplayName(requesterId);
      await notify({
        toUserId: otherParty(after, requesterId),
        type: "deletion_request",
        title: "Silme Talebi",
        message: `${requesterName}, ${amount} tutarındaki işlemi silmek ` +
          "istiyor.",
        debtId,
        debt: after,
        createdById: requesterId,
      });
      return;
    }

    // Silme talebi reddedildi: kayıt onaylı durumuna döndü.
    if (before.status === "pending_deletion" && after.status === "approved") {
      const requesterId = before["deletion_requester_id"];
      if (!requesterId) return;
      const responderId = otherParty(before, requesterId);
      const responderName = await getDisplayName(responderId);
      await notify({
        toUserId: requesterId,
        type: "deletion_rejected",
        title: "Silme Talebi Reddedildi",
        message: `${responderName}, ${amount} tutarındaki işlemin ` +
          "silinmesini reddetti.",
        debtId,
        debt: after,
        createdById: responderId,
      });
    }
  }
);

// Silme talebi onaylandı: kurallar yalnızca karşı tarafın silmesine izin verir.
export const onDebtDelete = onDocumentDeleted(
  {
    document: "debts/{debtId}",
    region: REGION,
  },
  async (event) => {
    const debt = event.data?.data() as DebtData | undefined;
    if (!debt || debt.status !== "pending_deletion") return;
    const requesterId = debt["deletion_requester_id"];
    if (!requesterId) return;

    const responderId = otherParty(debt, requesterId);
    const responderName = await getDisplayName(responderId);
    await notify({
      toUserId: requesterId,
      type: "deletion_approved",
      title: "Silme Talebi Onaylandı",
      message: `${responderName}, ${formatAmount(debt.miktar)} tutarındaki ` +
        "işlemin silinmesini onayladı.",
      debtId: event.params.debtId,
      debt,
      createdById: responderId,
    });
  }
);

/**
 * E-postası doğrulanmış ve profili olan kullanıcıyı bulur.
 *
 * users koleksiyonu istemciye listelenmez; kişi ekleme ve borç oluşturma
 * bu fonksiyonla Firebase Auth kaydına göre eşleşir. Profil e-postası
 * değiştirilerek başka birinin yerine geçilemez.
 */
export const lookupUserByEmail = onCall<{email?: unknown}>(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Giriş yapmalısınız.");
    }
    const raw = request.data?.email;
    const email = typeof raw === "string" ? raw.trim().toLowerCase() : "";
    if (!email || email.length > 254 || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "Geçerli bir e-posta girin.");
    }

    let user: admin.auth.UserRecord;
    try {
      user = await admin.auth().getUserByEmail(email);
    } catch (error) {
      if ((error as {code?: string}).code === "auth/user-not-found") {
        return {found: false};
      }
      throw error;
    }
    if (!user.emailVerified) return {found: false};

    const profile = await db.collection("users").doc(user.uid).get();
    if (!profile.exists) return {found: false};

    return {
      found: true,
      uid: user.uid,
      email: user.email ?? email,
      adSoyad: profile.get("adSoyad") ?? user.displayName ?? "",
    };
  }
);

export const dueDateReminder = onSchedule(
  {
    schedule: "every day 08:00",
    timeZone: "Europe/Istanbul",
    region: REGION,
  },
  async () => {
    logger.info("dueDateReminder triggered!");
    await processDueReminders();
  }
);

/**
 * Vadesi bugün olan borçlar için hatırlatma gönderir.
 */
async function processDueReminders() {
  const now = admin.firestore.Timestamp.now();
  const todayStart = new admin.firestore.Timestamp(
    now.seconds - (now.seconds % 86400),
    0
  );
  const todayEnd = new admin.firestore.Timestamp(
    todayStart.seconds + 86400 - 1,
    999
  );

  const snapshot = await db
    .collection("debts")
    .where("tahminiOdemeTarihi", ">=", todayStart)
    .where("tahminiOdemeTarihi", "<=", todayEnd)
    .get();

  if (snapshot.empty) {
    logger.info("No due debts found to send reminders for.");
    return;
  }

  logger.info(`Sending reminders for ${snapshot.size} debts.`);

  const batch = db.batch();
  const pushPromises: Promise<void>[] = [];

  for (const doc of snapshot.docs) {
    const d = doc.data() as DebtData;
    if (d.dueReminderSent === true) {
      continue; // daha önce işlenmiş
    }

    const creditorName = await getDisplayName(d.alacakliId);
    const amount = formatAmount(d.miktar);

    pushPromises.push(
      sendPushNotification(
        d.borcluId,
        "Ödeme Hatırlatması",
        `${creditorName} için ${amount} tutarında ödemeniz bugün vadesinde.`,
        {type: "due_reminder", relatedDebtId: doc.id}
      )
    );

    batch.set(db.collection("notifications").doc(), {
      toUserId: d.borcluId,
      type: "due_reminder",
      relatedDebtId: doc.id,
      message: `${creditorName} için ${amount} tutarındaki ödemenizin ` +
        "tahmini tarihi bugün.",
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdById: d.alacakliId,
      creditorId: d.alacakliId,
      debtorId: d.borcluId,
      amount: d.miktar,
    });

    batch.update(doc.ref, {dueReminderSent: true});
  }

  await Promise.all([...pushPromises, batch.commit()]);

  logger.info("Reminders and updates completed successfully.");
}
