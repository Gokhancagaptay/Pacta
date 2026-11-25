import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {admin, db} from "./firebase";

/** Cihazın artık geçerli olmadığını gösteren FCM hataları. */
const DEAD_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

/**
 * Kullanıcının tüm cihazlarına FCM push bildirimi gönderir. Geçersiz
 * anahtarlar (cihaz çıkış yaptı, uygulama kaldırıldı) hesaptan silinir;
 * yalnızca hata veren anahtar silinir, bu arada kaydedilen yenisi kalır.
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
    const listed = (userDoc.get("fcmTokens") as string[] | undefined) ?? [];
    const legacy = userDoc.get("fcmToken") as string | undefined;
    const tokens = [...new Set([...listed, ...(legacy ? [legacy] : [])])];

    if (tokens.length === 0) {
      logger.warn(`[push] FCM token yok, atlandı: ${toUserId}`);
      return;
    }
    const result = await admin.messaging().sendEachForMulticast({
      tokens,
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
    const dead = tokens.filter((_, i) => {
      const code = result.responses[i].error?.code;
      return code !== undefined && DEAD_TOKEN_CODES.has(code);
    });
    if (dead.length > 0) {
      const update: {[field: string]: unknown} = {
        fcmTokens: FieldValue.arrayRemove(...dead),
      };
      if (legacy && dead.includes(legacy)) {
        update.fcmToken = FieldValue.delete();
      }
      await db.collection("users").doc(toUserId).update(update)
        .catch(() => undefined);
      logger.info(`[push] Geçersiz anahtar silindi: ${toUserId}`,
        {count: dead.length});
    }
    logger.info(`[push] Gönderildi: ${toUserId}`,
      {success: result.successCount, failure: result.failureCount});
  } catch (error) {
    const err = error as {message?: string; code?: string; stack?: string};
    logger.error(`[push] Gönderilemedi: ${toUserId}`, {
      errorMessage: err.message,
      errorCode: err.code,
      errorStack: err.stack,
    });
  }
}
