import {db} from "./firebase";

/**
 * Bir sorgunun tüm belgelerini 400'lük parçalar hâlinde siler.
 * @param {FirebaseFirestore.Query} query Sorgu.
 * @return {Promise<number>} Silinen belge sayısı.
 */
export async function deleteQuery(
  query: FirebaseFirestore.Query
): Promise<number> {
  let deleted = 0;
  for (;;) {
    const snap = await query.limit(400).get();
    if (snap.empty) return deleted;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    deleted += snap.size;
  }
}
