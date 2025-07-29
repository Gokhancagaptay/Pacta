import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

// Firebase Admin SDK'sını başlat.
// Bu, Cloud Function'ımızın projedeki diğer Firebase servisleriyle
// (Firestore, Messaging vb.) etkileşime girmesini sağlar.
admin.initializeApp();

// "sendNotificationOnCreate" adında yeni bir Cloud Function tanımlıyoruz.
// Bu fonksiyon, "notifications" koleksiyonundaki herhangi bir dokümana
// yeni bir veri yazıldığında tetiklenecek.
export const sendnotificationoncreate = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    logger.info("Function triggered by new notification document.");

    // 1. Yeni oluşturulan bildirim verisini al.
    const snapshot = event.data;
    if (!snapshot) {
      logger.log("No data associated with the event, exiting.");
      return;
    }
    const notificationData = snapshot.data();

    const toUserId = notificationData.toUserId;
    const title = notificationData.title;
    // Flutter tarafında 'massage' olarak isimlendirmiştik.
    const body = notificationData.massage;

    if (!toUserId) {
      logger.log("Missing toUserId in notification data, exiting.");
      return;
    }

    // 2. Alıcının kullanıcı dokümanından FCM token'ını al.
    const userDocRef = admin.firestore().collection("users").doc(toUserId);
    const userDoc = await userDocRef.get();

    if (!userDoc.exists) {
      logger.warn(`User document not found for toUserId: ${toUserId}`);
      return;
    }

    const userData = userDoc.data();
    if (!userData || !userData.fcmToken) {
      logger.warn(`FCM token not found for user: ${toUserId}`);
      return;
    }

    const token = userData.fcmToken;

    // 3. Anlık bildirim yükünü (payload) hazırla.
    const payload = {
      notification: {
        title: title || "Yeni bir bildiriminiz var!",
        body: body || "Detayları görmek için dokunun.",
      },
      token: token,
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    // 4. Hazırlanan bildirimi gönder.
    try {
      logger.log(`Sending notification to token: ${token}`);
      const response = await admin.messaging().send(payload);
      logger.info("Successfully sent message:", response);
    } catch (error) {
      logger.error("Error sending message:", error);
    }
  },
);
