// functions/src/index.ts
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
// DÜZELTME: Güvenilirliği en yüksek olan onSchedule metoduna geri dönüldü.
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

const db = admin.firestore();

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
  data: { [key: string]: string }
) {
  logger.info(`[sendPushNotification] Entered for user: ${toUserId}`, data);
  try {
    const userDoc = await db.collection("users").doc(toUserId).get();
    const fcmToken = userDoc.data()?.fcmToken as string | undefined;

    if (fcmToken) {
      logger.info(`[sendPushNotification] FCM token found for user ${toUserId}. Sending message.`);
      await admin.messaging().send({
        token: fcmToken,
        notification: { title, body },
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
      logger.info(`[sendPushNotification] Push notification sent successfully to ${toUserId}`);
    } else {
      logger.warn(`[sendPushNotification] FCM token not found for user ${toUserId}. Skipping push.`);
    }
  } catch (error: any) {
    logger.error(`[sendPushNotification] Failed to send push notification to ${toUserId}`, {
      errorMessage: error.message,
      errorCode: error.code, // Hata kodunu logla
      errorStack: error.stack,
    });
  }
}

export const onDebtCreate = onDocumentCreated(
  {
    document: "debts/{debtId}",
    region: "europe-west1",
  },
  async (event) => {
    logger.info(`[onDebtCreate] Function triggered for debtId: ${event.params.debtId}`);
    const debtId = event.params.debtId;
    const debtData = event.data?.data();

    if (!debtData) {
      logger.warn("[onDebtCreate] debtData is missing. Exiting.");
      return;
    }
    logger.info("[onDebtCreate] debtData exists.", debtData);
    const {
      createdBy,
      alacakliId,
      borcluId,
      miktar,
      status,
    } = debtData;

    const notificationPayload = {
      relatedDebtId: debtId,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      creditorId: alacakliId,
      debtorId: borcluId,
    };

    logger.info("[onDebtCreate] Fetching user documents...");
    const creditorDoc = await db.collection("users").doc(alacakliId).get();
    const debtorDoc = await db.collection("users").doc(borcluId).get();
    logger.info("[onDebtCreate] Fetched user documents successfully.");

    const creditorName =
      creditorDoc.data()?.adSoyad ?? creditorDoc.data()?.email ?? "Bilinmeyen";
    const debtorName =
      debtorDoc.data()?.adSoyad ?? debtorDoc.data()?.email ?? "Bilinmeyen";

    if (status === "note") {
      logger.info("[onDebtCreate] Status is 'note'. Exiting.");
      return;
    }

    let toUserId: string;
    let notificationMessage: string;
    let notificationTitle: string;

    if (createdBy === alacakliId) {
      toUserId = borcluId;
      notificationTitle = "Yeni Borç Bildirimi";
      notificationMessage = `${creditorName} size ${miktar}₺ tutarında bir borç bildiriminde bulundu.`;
    } else if (createdBy === borcluId) {
      toUserId = alacakliId;
      notificationTitle = "Yeni Alacak Talebi";
      notificationMessage = `${debtorName} sizden ${miktar}₺ tutarında bir talepte bulundu.`;
    } else {
      logger.warn("[onDebtCreate] createdBy does not match alacakliId or borcluId. Exiting.");
      return; // Olayla ilgisi olmayan durum
    }

    logger.info(`[onDebtCreate] Determined notification recipient: ${toUserId}`);

    const notificationData = {
      ...notificationPayload,
      toUserId: toUserId,
      title: notificationTitle,
      message: notificationMessage,
      type: "approval_request",
    };

    logger.info("[onDebtCreate] Notification data prepared. Writing to Firestore...");
    await db.collection("notifications").add(notificationData);
    logger.info("[onDebtCreate] Notification written to Firestore successfully.");

    logger.info(`[onDebtCreate] Calling sendPushNotification for user ${toUserId}...`);
    await sendPushNotification(
      toUserId,
      notificationTitle,
      notificationMessage,
      { type: "approval_request", relatedDebtId: debtId }
    );
    logger.info(`[onDebtCreate] Finished sendPushNotification call for user ${toUserId}.`);
  }
);

export const onDebtStatusUpdate = onDocumentUpdated(
  {
    document: "debts/{debtId}",
    region: "europe-west1",
  },
  async (event) => {
    // Bu fonksiyonun içeriği de aynı kalıyor...
    logger.info("onDebtStatusUpdate tetiklendi", { debtId: event.params.debtId });
    if (!event.data) { return; }

    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status !== "pending" || after.status === "pending") { return; }
    const { alacakliId, borcluId, miktar, status } = after;
    const debtId = event.params.debtId;
    const updatedById = after.updatedById;
    if (!updatedById) { return; }

    const creditorDoc = await db.collection("users").doc(alacakliId).get();
    const debtorDoc = await db.collection("users").doc(borcluId).get();
    const creditorName = creditorDoc.data()?.adSoyad ?? creditorDoc.data()?.email ?? "Bilinmeyen";
    const debtorName = debtorDoc.data()?.adSoyad ?? debtorDoc.data()?.email ?? "Bilinmeyen";

    let toUserId: string;
    let title: string;
    let message: string;
    let notificationType: string;

    if (status === "approved") {
      title = "Talep Onaylandı";
      notificationType = "request_approved";
      if (updatedById === alacakliId) {
        toUserId = borcluId;
        message = `${miktar}₺ tutarındaki alacak talebiniz ${creditorName} tarafından onaylandı.`;
      } else {
        toUserId = alacakliId;
        message = `${miktar}₺ tutarındaki borç bildiriminiz ${debtorName} tarafından onaylandı.`;
      }
    } else if (status === "rejected") {
      title = "Talep Reddedildi";
      notificationType = "request_rejected";
      if (updatedById === alacakliId) {
        toUserId = borcluId;
        message = `${miktar}₺ tutarındaki alacak talebiniz ${creditorName} tarafından reddedildi.`;
      } else {
        toUserId = alacakliId;
        message = `${miktar}₺ tutarındaki borç bildiriminiz ${debtorName} tarafından reddedildi.`;
      }
    } else {
      return;
    }

    const notification = {
      toUserId: toUserId,
      relatedDebtId: debtId,
      title: title,
      message: message,
      type: notificationType,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      creditorId: alacakliId,
      debtorId: borcluId,
    };
    await db.collection("notifications").add(notification);

    await sendPushNotification(toUserId, title, message, {
      type: notificationType,
      relatedDebtId: debtId,
    });
  }
);

export const dueDateReminder = onSchedule(
  {
    schedule: "every day 08:00",
    timeZone: "Europe/Istanbul",
    region: "europe-west1",
  },
  // The 'event' parameter is removed here, as it's not being used.
  async () => {
    logger.info("dueDateReminder triggered!");
    await processDueReminders();
  }
);

// Manuel tetikleme (test amaçlı): /runDueReminderNow
export const runDueReminderNow = onRequest({ region: "europe-west1" }, async (_req, res) => {
  try {
    await processDueReminders();
    res.status(200).send("dueDateReminder executed");
  } catch (e) {
    logger.error("Manual trigger failed", e as any);
    res.status(500).send("error");
  }
});

async function processDueReminders() {
  logger.info("processDueReminders started");
  const now = admin.firestore.Timestamp.now();
  const todayStart = new admin.firestore.Timestamp(now.seconds - (now.seconds % 86400), 0);
  const todayEnd = new admin.firestore.Timestamp(todayStart.seconds + 86400 - 1, 999);

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
  const pushPromises: Promise<void>[] = []; // Push bildirimleri için promise dizisi

  for (const doc of snapshot.docs) {
    const d = doc.data() as any;
    const { borcluId, alacakliId, miktar } = d;
    if (d.dueReminderSent === true) {
      continue; // daha önce işlenmiş
    }

    const creditorDoc = await db.collection("users").doc(alacakliId).get();
    const creditorName =
      creditorDoc.data()?.adSoyad ?? creditorDoc.data()?.email ?? "Unknown";

    // Push bildirimini promise dizisine ekle, ama bekleme (await yok)
    const title = "Ödeme Hatırlatması";
    const body = `${creditorName} için ${miktar}₺ tutarında ödemeniz bugün vadesinde.`;
    pushPromises.push(
      sendPushNotification(borcluId, title, body, {
        type: "due_reminder",
        relatedDebtId: doc.id,
      })
    );

    const notificationData = {
      toUserId: borcluId,
      type: "due_reminder",
      relatedDebtId: doc.id,
      message: `${creditorName} için ${miktar}₺ tutarındaki ödemenizin tahmini tarihi bugün.`,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdById: alacakliId,
      creditorId: alacakliId,
      debtorId: borcluId,
      amount: miktar,
    };

    const notificationRef = db.collection("notifications").doc();
    batch.set(notificationRef, notificationData);

    batch.update(doc.ref, { dueReminderSent: true });
  }

  // Döngü bittikten sonra TÜM işlemleri aynı anda çalıştır.
  await Promise.all([
    ...pushPromises, // Tüm push bildirimlerini gönder
    batch.commit(),    // ve Firestore'a tüm güncellemeleri yaz.
  ]);

  logger.info("Reminders and updates completed successfully.");
}