import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {admin, db} from "./firebase";

/**
 * Kullanıcıya FCM üzerinden push bildirimi gönderir.
 * @param {string} toUserId Alıcı kullanıcı ID'si.
 * @param {string} title Bildirim başlığı.
 * @param {string} body Bildirim içeriği.
 * @param {object} data Bildirimle gönderilecek ek veri.
 */
export async function sendPushNotification(
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
    // Cihaz çıkış yaptı ya da uygulama kaldırıldı: eski anahtar silinir.
    if (
      err.code === "messaging/registration-token-not-registered" ||
      err.code === "messaging/invalid-registration-token"
    ) {
      await db.collection("users").doc(toUserId)
        .update({fcmToken: FieldValue.delete()})
        .catch(() => undefined);
      logger.info(`[push] Geçersiz anahtar silindi: ${toUserId}`);
      return;
    }
    logger.error(`[push] Gönderilemedi: ${toUserId}`, {
      errorMessage: err.message,
      errorCode: err.code,
      errorStack: err.stack,
    });
  }
}
