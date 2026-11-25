import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {REGION, db} from "../common/firebase";
import {isDeletedAccount} from "./callable";
import {Ledger, sideOf} from "./model";

// Kişi profilindeki adını değiştirince defterlerdeki görünen adı da
// güncellenir: karşı tarafın listesi ve bildirimler eski adı göstermez.

/** Defterde ve bildirimlerde görünen adın üst sınırı (commands.ts ile aynı). */
const MAX_NAME = 80;

/**
 * Tek satıra indirilmiş, kısaltılmış ad; boşsa null.
 * @param {unknown} raw Profildeki ad.
 * @return {string | null} Görünen ad.
 */
export function cleanName(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const name = raw.replace(/\s+/g, " ").trim().slice(0, MAX_NAME);
  return name || null;
}

/**
 * Kişinin taraf olduğu tüm defterlerde görünen adını günceller. Hesabını
 * silmiş tarafın adına dokunulmaz ("Silinmiş kullanıcı" kalır).
 * @param {string} uid Kişi.
 * @param {string} name Yeni ad.
 * @return {Promise<number>} Güncellenen defter sayısı.
 */
export async function propagateName(
  uid: string,
  name: string
): Promise<number> {
  const ledgers = await db.collection("ledgers")
    .where("memberUids", "array-contains", uid).get();
  let batch = db.batch();
  let ops = 0;
  let updated = 0;
  for (const doc of ledgers.docs) {
    const ledger = doc.data() as Ledger;
    const side = sideOf(ledger, uid);
    if (!side || ledger.sides[side].deleted) continue;
    if (ledger.sides[side].displayName === name) continue;
    batch.update(doc.ref, {[`sides.${side}.displayName`]: name});
    ops++;
    updated++;
    if (ops === 400) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) await batch.commit();
  return updated;
}

export const onUserProfileWritten = onDocumentWritten(
  {document: "users/{uid}", region: REGION, retry: true},
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const name = cleanName(after.get("adSoyad"));
    const before = cleanName(event.data?.before.get("adSoyad"));
    // Bildirim anahtarı, favori gibi diğer alan değişiklikleri erken döner.
    if (!name || name === before) return;
    if (await isDeletedAccount(event.params.uid)) return;
    await propagateName(event.params.uid, name);
  }
);
