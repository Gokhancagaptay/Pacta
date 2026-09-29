import {
  DocumentSnapshot,
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import {REGION, db} from "../common/firebase";
import {sendPushNotification} from "../common/push";

// Bildirim iki adımdır: komut uygulama içi bildirimi yazar ve hemen yanıt
// verir; push'u, bildirim belgesi oluşunca onNotificationCreated gönderir
// (kullanıcı, işlemin push gönderilmesini beklemez).

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
 * Uygulama içi bildirim belgesi (users/{uid}/notifications).
 * @param {Notice} n Bildirim.
 * @return {object} Belge alanları.
 */
export function notificationData(n: Notice) {
  return {
    type: n.type,
    title: n.title,
    message: n.message,
    ledgerId: n.ledgerId,
    entryId: n.entryId,
    route: routeOf(n),
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
    // Push için: hangi ayar açıp kapatır, gece gelirse ne zamana kalır.
    setting: n.setting,
    pushAfter: n.pushAfter ? Timestamp.fromDate(n.pushAfter) : null,
  };
}

/**
 * Kullanıcı izin veriyorsa push gönderir (sessiz saatteyse kuyruğa alır).
 * Uygulama içi bildirim ayrıca yazılmış olmalıdır. Silinmiş hesaba gitmez.
 * @param {Notice} n Bildirim.
 * @param {DocumentSnapshot} user Alıcının kullanıcı belgesi.
 */
async function push(n: Notice, user: DocumentSnapshot): Promise<void> {
  if (!user.exists) return;
  if (user.get(`notificationSettings.${n.setting}`) === false) return;
  if (
    n.setting === "reminders" &&
    user.get(`reminderMutes.${n.ledgerId}`) === true
  ) {
    return;
  }
  const data = {
    type: n.type,
    ledgerId: n.ledgerId,
    entryId: n.entryId ?? "",
    route: routeOf(n),
  };
  if (n.pushAfter) {
    await db.collection("pushQueue").add({
      uid: n.uid,
      title: n.title,
      message: n.message,
      data,
      sendAfter: Timestamp.fromDate(n.pushAfter),
    });
    return;
  }
  await sendPushNotification(n.uid, n.title, n.message, data);
}

/**
 * Uygulama içi bildirimi yazar; push'u tetikleyici gönderir. Alıcının
 * hesabı silinmişse hiçbir şey yazılmaz (sahipsiz belge kalmasın).
 * Transaction commit edildikten sonra çağrılır; hata işlemi geri almaz.
 * @param {Notice[]} notices Bildirimler.
 */
export async function deliver(notices: Notice[]): Promise<void> {
  await Promise.all(notices.map(async (n) => {
    try {
      const userRef = db.collection("users").doc(n.uid);
      const user = await userRef.get();
      if (!user.exists) return;
      await userRef.collection("notifications").add(notificationData(n));
    } catch (error) {
      logger.error(`[ledger] Bildirim yazılamadı: ${n.uid}`, error);
    }
  }));
}

/**
 * Bildirim belgesinden push: kullanıcı izin veriyorsa gönderir, sessiz
 * saatteyse kuyruğa alır. Hatırlatmalarda alıcı o kişiyi sessize aldıysa
 * gitmez; gönderen bunu bilmez.
 * @param {string} uid Alıcı.
 * @param {FirebaseFirestore.DocumentData} data Bildirim belgesi.
 */
export async function pushForNotification(
  uid: string,
  data: FirebaseFirestore.DocumentData
): Promise<void> {
  // Eski biçimdeki (ayarı yazılmamış) bildirimler için push yok.
  if (!data.setting) return;
  const n: Notice = {
    uid,
    setting: data.setting,
    type: data.type,
    title: data.title,
    message: data.message,
    ledgerId: data.ledgerId,
    entryId: data.entryId ?? null,
    pushAfter: (data.pushAfter as Timestamp | null)?.toDate(),
  };
  await push(n, await db.collection("users").doc(uid).get());
}

export const onNotificationCreated = onDocumentCreated(
  {document: "users/{uid}/notifications/{notificationId}", region: REGION},
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    try {
      await pushForNotification(event.params.uid, data);
    } catch (error) {
      logger.error(`[ledger] Push gönderilemedi: ${event.params.uid}`, error);
    }
  }
);

/**
 * Sessiz saatlerde bekletilen push'ları gönderir.
 * @param {Date} now An.
 * @return {Promise<number>} Gönderilen sayısı.
 */
export async function flushPushQueue(now: Date): Promise<number> {
  // Günde bir kez çalışır; birikenler 500'lük parçalar hâlinde boşaltılır.
  let sent = 0;
  for (;;) {
    const due = await db.collection("pushQueue")
      .where("sendAfter", "<=", Timestamp.fromDate(now))
      .limit(500)
      .get();
    for (const doc of due.docs) {
      const q = doc.data();
      await sendPushNotification(q.uid, q.title, q.message, q.data);
      await doc.ref.delete();
    }
    sent += due.size;
    if (due.size < 500) return sent;
  }
}
