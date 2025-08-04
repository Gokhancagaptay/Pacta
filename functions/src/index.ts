// functions/src/index.ts
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

export const onDebtCreate = onDocumentCreated(
  {
    document: "debts/{debtId}",
    region: "europe-west1",
  },
  async (event) => {
    console.log("DEBUG: onDebtCreate triggered");
    const snap = event.data;
    if (!snap) {
      console.error("No data associated with the event.");
      return;
    }
    const debtData = snap.data();
    if (!debtData) {
      console.error("Debt data is undefined.");
      return;
    }
    
    console.log("DEBUG: Debt data received:", debtData);

    // DebtModel'deki alan adlarını kullan
    const { createdBy, alacakliId, borcluId, miktar } = debtData;
    const debtId = event.params.debtId;

    // Alacaklı ve borçlu adlarını al
    const creditorDoc = await db.collection("users").doc(alacakliId).get();
    const debtorDoc = await db.collection("users").doc(borcluId).get();

    const creditorName = creditorDoc.data()?.adSoyad ?? creditorDoc.data()?.email ?? "Bilinmeyen";
    const debtorName = debtorDoc.data()?.adSoyad ?? debtorDoc.data()?.email ?? "Bilinmeyen";

    console.log("DEBUG: Creator:", createdBy, "Creditor:", alacakliId, "Debtor:", borcluId);

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

    // If the creator is the creditor, it's a "pacta ver" (lend) transaction.
    // Notification goes to the debtor.
    if (createdBy === alacakliId) {
      console.log("DEBUG: PACTA VER - Sending notification to debtor");
      notification = {
        ...notificationPayload,
        toUserId: borcluId,
        title: `Yeni Borç Bildirimi`,
        message: `${creditorName} size ${miktar}₺ tutarında bir borç bildiriminde bulundu.`,
        type: "approval_request",
      };
      await db.collection("notifications").add(notification);
      console.log("DEBUG: Notification sent to:", borcluId);
    }
    // If the creator is the debtor, it's a "pacta al" (request) transaction.
    // Notification goes to the creditor.
    else if (createdBy === borcluId) {
      console.log("DEBUG: PACTA AL - Sending notification to creditor");
      notification = {
        ...notificationPayload,
        toUserId: alacakliId,
        title: `Yeni Alacak Talebi`,
        message: `${debtorName} sizden ${miktar}₺ tutarında bir talepte bulundu.`,
        type: "approval_request",
      };
      await db.collection("notifications").add(notification);
      console.log("DEBUG: Notification sent to:", alacakliId);
    } else {
      console.log("DEBUG: Creator is neither creditor nor debtor. No notification sent.");
    }
  }
);

export const onDebtStatusUpdate = onDocumentUpdated(
  {
    document: "debts/{debtId}",
    region: "europe-west1",
  },
  async (event) => {
    const change = event.data;
    if (!change) {
      console.error("No data associated with the event.");
      return;
    }
    const before = change.before.data();
    const after = change.after.data();

    if (!before || !after) {
      console.error("Before or after data is missing.");
      return;
    }

    // Status 'pending' durumundan değişti mi diye kontrol et
    if (before.status !== "pending" || after.status === "pending") {
      return null;
    }
    
    // DebtModel'deki alan adlarını kullan
    const { alacakliId, borcluId, miktar, status } = after;
    const debtId = event.params.debtId;
    // Onay/Ret işlemini yapan kullanıcının ID'si
    const updatedById = after.updatedById; 

    if (!updatedById) {
      console.log(
        "Update triggered without 'updatedById'. Skipping."
      );
      return null;
    }

    const creditorDoc = await db.collection("users").doc(alacakliId).get();
    const debtorDoc = await db.collection("users").doc(borcluId).get();

    const creditorName = creditorDoc.data()?.adSoyad ?? creditorDoc.data()?.email ?? "Bilinmeyen";
    const debtorName = debtorDoc.data()?.adSoyad ?? debtorDoc.data()?.email ?? "Bilinmeyen";

    let toUserId, title, message, notificationType;

    if (status === "approved") {
      title = "Talep Onaylandı";
      notificationType = "request_approved";
      // Bildirimi karşı tarafa gönder
      if (updatedById === alacakliId) {
        // Alacaklı onayladı, borçluya bildir
        toUserId = borcluId;
        message = `${miktar}₺ tutarındaki alacak talebiniz ${creditorName} tarafından onaylandı.`;
      } else {
        // Borçlu onayladı, alacaklıya bildir
        toUserId = alacakliId;
        message = `${miktar}₺ tutarındaki borç bildiriminiz ${debtorName} tarafından onaylandı.`;
      }
    } else if (status === "rejected") {
      title = "Talep Reddedildi";
      notificationType = "request_rejected";
      // Bildirimi karşı tarafa gönder
      if (updatedById === alacakliId) {
        // Alacaklı reddetti, borçluya bildir
        toUserId = borcluId;
        message = `${miktar}₺ tutarındaki alacak talebiniz ${creditorName} tarafından reddedildi.`;
      } else {
        // Borçlu reddetti, alacaklıya bildir
        toUserId = alacakliId;
        message = `${miktar}₺ tutarındaki borç bildiriminiz ${debtorName} tarafından reddedildi.`;
      }
    } else {
      return null;
    }

    // Karşı taraf için yeni bildirim belgesi oluştur
    const notification = {
      toUserId: toUserId,
      relatedDebtId: debtId,
      title: title,
      message: message,
      amount: miktar,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      type: notificationType,
      createdById: updatedById, // İşlemi yapan kişi
      creditorId: alacakliId,
      debtorId: borcluId,
    };

    return db.collection("notifications").add(notification);
  }
);