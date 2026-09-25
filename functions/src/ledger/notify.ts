import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {db} from "../common/firebase";
import {sendPushNotification} from "../common/push";

export interface Notice {
  uid: string;
  /** Push'u açıp kapatan kullanıcı ayarı (users.notificationSettings). */
  setting: "newDebtRequests" | "statusChanges";
  type: string;
  title: string;
  message: string;
  ledgerId: string;
  entryId: string;
}

/**
 * Uygulama içi bildirimi yazar; kullanıcı izin veriyorsa push gönderir.
 * Transaction commit edildikten sonra çağrılır; hata işlemi geri almaz.
 * @param {Notice[]} notices Bildirimler.
 */
export async function deliver(notices: Notice[]): Promise<void> {
  for (const n of notices) {
    try {
      const route = `/l/${n.ledgerId}/e/${n.entryId}`;
      await db.collection("users").doc(n.uid)
        .collection("notifications").add({
          type: n.type,
          title: n.title,
          message: n.message,
          ledgerId: n.ledgerId,
          entryId: n.entryId,
          route,
          isRead: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      const user = await db.collection("users").doc(n.uid).get();
      const enabled = user.get(`notificationSettings.${n.setting}`);
      if (enabled === false) continue;
      await sendPushNotification(n.uid, n.title, n.message, {
        type: n.type,
        ledgerId: n.ledgerId,
        entryId: n.entryId,
        route,
      });
    } catch (error) {
      logger.error(`[ledger] Bildirim gönderilemedi: ${n.uid}`, error);
    }
  }
}
