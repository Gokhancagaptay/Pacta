// functions/src/index.ts
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
// DÜZELTME: Güvenilirliği en yüksek olan onSchedule metoduna geri dönüldü.
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

const db = admin.firestore();

export const onDebtCreate = onDocumentCreated(
  {
    document: "debts/{debtId}",
    region: "europe-west1",
  },
  async (event) => {
    // Bu fonksiyonun içeriği aynı kalıyor...
    logger.info("onDebtCreate tetiklendi", { debtId: event.params.debtId });
    const snap = event.data;
    if (!snap) {
      logger.error("Olayla ilişkili veri yok.");
      return;
    }
    const debtData = snap.data();
    if (!debtData) {
      logger.error("Borç verisi tanımsız.");
      return;
    }
    const { createdBy, alacakliId, borcluId, miktar, status } = debtData;
    const debtId = event.params.debtId;
    const creditorDoc = await db.collection("users").doc(alacakliId).get();
    const debtorDoc = await db.collection("users").doc(borcluId).get();
    const creditorName = creditorDoc.data()?.adSoyad ?? creditorDoc.data()?.email ?? "Bilinmeyen";
    const debtorName = debtorDoc.data()?.adSoyad ?? debtorDoc.data()?.email ?? "Bilinmeyen";
    const notificationPayload = {
      relatedDebtId: debtId,
      amount: miktar,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdById: createdBy,
      creditorId: alacakliId,
      debtorId: borcluId,
    };
    let notification;
    if (status === "note") {
      logger.info("NOTE kaydı oluşturuldu - bildirim gönderilmeyecek.");
      return;
    }
    if (createdBy === alacakliId) {
      notification = {
        ...notificationPayload,
        toUserId: borcluId,
        title: "Yeni Borç Bildirimi",
        message: `${creditorName} size ${miktar}₺ tutarında bir borç bildiriminde bulundu.`,
        type: "approval_request",
      };
      await db.collection("notifications").add(notification);
    } else if (createdBy === borcluId) {
      notification = {
        ...notificationPayload,
        toUserId: alacakliId,
        title: "Yeni Alacak Talebi",
        message: `${debtorName} sizden ${miktar}₺ tutarında bir talepte bulundu.`,
        type: "approval_request",
      };
      await db.collection("notifications").add(notification);
    }
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
    const change = event.data;
    if (!change) { return; }
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after) { return; }
    if (before.status !== "pending" || after.status === "pending") { return; }
    const { alacakliId, borcluId, miktar, status } = after;
    const debtId = event.params.debtId;
    const updatedById = after.updatedById;
    if (!updatedById) { return; }
    const creditorDoc = await db.collection("users").doc(alacakliId).get();
    const debtorDoc = await db.collection("users").doc(borcluId).get();
    const creditorName = creditorDoc.data()?.adSoyad ?? creditorDoc.data()?.email ?? "Bilinmeyen";
    const debtorName = debtorDoc.data()?.adSoyad ?? debtorDoc.data()?.email ?? "Bilinmeyen";
    let toUserId, title, message, notificationType;
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
      amount: miktar,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      type: notificationType,
      createdById: updatedById,
      creditorId: alacakliId,
      debtorId: borcluId,
    };
    await db.collection("notifications").add(notification);
  }
);

// ANA DÜZELTME: Fonksiyon, en doğru ve basit hali olan onSchedule'a geri döndürüldü.
// Tüm izinleri ve ayarları düzelttiğimiz için artık bu metodun çalışması gerekiyor.
async function processDueReminders() {
  logger.info("processDueReminders started");

  // Europe/Istanbul gün başlangıcı/bitişi (library'siz basit hesap)
  const now = new Date();
  const trNow = new Date(
    new Intl.DateTimeFormat("en-CA", {
      timeZone: "Europe/Istanbul",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false,
    })
      .format(now)
      .replace(",", "")
  );
  const trStart = new Date(trNow);
  trStart.setHours(0, 0, 0, 0);
  const trEnd = new Date(trNow);
  trEnd.setHours(23, 59, 59, 999);

  const todayStart = admin.firestore.Timestamp.fromDate(trStart);
  const todayEnd = admin.firestore.Timestamp.fromDate(trEnd);

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
  for (const doc of snapshot.docs) {
    const d = doc.data() as any;
    const { borcluId, alacakliId, miktar } = d;
    if (d.dueReminderSent === true) {
      continue; // daha önce işlenmiş
    }

    const creditorDoc = await db.collection("users").doc(alacakliId).get();
    const creditorName =
      creditorDoc.data()?.adSoyad ?? creditorDoc.data()?.email ?? "Unknown";

    // OS push bildirimi (FCM) — varsa token gönder
    try {
      const debtorDoc = await db.collection("users").doc(borcluId).get();
      const fcmToken = debtorDoc.data()?.fcmToken as string | undefined;
      if (fcmToken) {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: "Ödeme Hatırlatması",
            body: `${creditorName} için ${miktar}₺ tutarında ödemeniz bugün vadesinde.`,
          },
          data: {
            type: "due_reminder",
            relatedDebtId: doc.id,
          },
        });
      }
    } catch (err) {
      logger.warn("FCM gönderimi atlandı", {
        debtId: doc.id,
        error: (err as Error).message,
      });
    }

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

  await batch.commit();
  logger.info("Reminders and updates completed successfully.");
}

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