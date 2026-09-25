import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {db} from "../common/firebase";
import {sendPushNotification} from "../common/push";

export interface Notice {
  uid: string;
  /** Push'u açıp kapatan kullanıcı ayarı (users.notificationSettings). */
  setting: "newDebtRequests" | "statusChanges" | "reminders";
  type: string;
  title: string;
  message: string;
  ledgerId: string;
  /** Yoksa bildirim defteri açar. */
  entryId: string | null;
  /** Verilirse push bu andan sonra gönderilir (sessiz saatler). */
  pushAfter?: Date;
}

/**
 * @param {Notice} n Bildirim.
 * @return {string} Uygulama içi rota.
 */
export function routeOf(n: Pick<Notice, "ledgerId" | "entryId">): string {
  return n.entryId ?
    `/l/${n.ledgerId}/e/${n.entryId}` :
    `/l/${n.ledgerId}`;
}

/**
 * Uygulama içi bildirimi yazar; kullanıcı izin veriyorsa push gönderir.
 * Hatırlatmalarda alıcı o kişiyi sessize aldıysa push gitmez; gönderen
 * bunu bilmez. Transaction commit edildikten sonra çağrılır; hata işlemi
 * geri almaz.
 * @param {Notice[]} notices Bildirimler.
 */
export async function deliver(notices: Notice[]): Promise<void> {
  for (const n of notices) {
    try {
      const route = routeOf(n);
      const userRef = db.collection("users").doc(n.uid);
      await userRef.collection("notifications").add({
        type: n.type,
        title: n.title,
        message: n.message,
        ledgerId: n.ledgerId,
        entryId: n.entryId,
        route,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
      const user = await userRef.get();
      if (user.get(`notificationSettings.${n.setting}`) === false) continue;
      if (
        n.setting === "reminders" &&
        user.get(`reminderMutes.${n.ledgerId}`) === true
      ) {
        continue;
      }
      const data = {
        type: n.type,
        ledgerId: n.ledgerId,
        entryId: n.entryId ?? "",
        route,
      };
      if (n.pushAfter) {
        await db.collection("pushQueue").add({
          uid: n.uid,
          title: n.title,
          message: n.message,
          data,
          sendAfter: Timestamp.fromDate(n.pushAfter),
        });
        continue;
      }
      await sendPushNotification(n.uid, n.title, n.message, data);
    } catch (error) {
      logger.error(`[ledger] Bildirim gönderilemedi: ${n.uid}`, error);
    }
  }
}

/**
 * Sessiz saatlerde bekletilen push'ları gönderir.
 * @param {Date} now An.
 * @return {Promise<number>} Gönderilen sayısı.
 */
export async function flushPushQueue(now: Date): Promise<number> {
  const due = await db.collection("pushQueue")
    .where("sendAfter", "<=", Timestamp.fromDate(now))
    .limit(500)
    .get();
  for (const doc of due.docs) {
    const q = doc.data();
    await sendPushNotification(q.uid, q.title, q.message, q.data);
    await doc.ref.delete();
  }
  return due.size;
}
