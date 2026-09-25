import {DocumentReference, Transaction} from "firebase-admin/firestore";
import {
  CallableRequest,
  FunctionsErrorCode,
  HttpsError,
} from "firebase-functions/v2/https";
import {z} from "zod";
import {REGION} from "../common/firebase";
import {Ledger, Side, sideOf} from "./model";

// Callable komutların ortak parçaları.
// App Check uygulamalar kaydedilince açılacak (plan §9).
export const OPTS = {region: REGION, enforceAppCheck: false};

export const Id = z.string().regex(/^[A-Za-z0-9_-]{8,128}$/);

/**
 * @param {FunctionsErrorCode} code Hata kodu.
 * @param {string} message Kullanıcıya gösterilebilir mesaj.
 */
export function fail(code: FunctionsErrorCode, message: string): never {
  throw new HttpsError(code, message);
}

/**
 * @param {CallableRequest<unknown>} req İstek.
 * @return {string} Oturumdaki kullanıcı.
 */
export function requireUid(req: CallableRequest<unknown>): string {
  if (!req.auth) fail("unauthenticated", "Giriş yapmalısınız.");
  return req.auth.uid;
}

/**
 * @param {z.ZodTypeAny} schema Şema.
 * @param {unknown} data Girdi.
 * @return {unknown} Doğrulanmış girdi.
 */
export function parse<T extends z.ZodTypeAny>(
  schema: T,
  data: unknown
): z.infer<T> {
  const result = schema.safeParse(data);
  if (!result.success) {
    const detail = result.error.issues
      .map((i) => `${i.path.join(".") || "girdi"}: ${i.message}`)
      .join("; ");
    fail("invalid-argument", detail);
  }
  return result.data;
}

/**
 * Defteri okur; üyelik ve durum kontrolü yapar.
 * @param {Transaction} tx Transaction.
 * @param {DocumentReference} ref Defter.
 * @param {string} uid Kullanıcı.
 * @return {Promise<object>} Defter ve kullanıcının tarafı.
 */
export async function readLedger(
  tx: Transaction,
  ref: DocumentReference,
  uid: string
): Promise<{ledger: Ledger; side: Side}> {
  const snap = await tx.get(ref);
  if (!snap.exists) fail("not-found", "Defter bulunamadı.");
  const ledger = snap.data() as Ledger;
  const side = sideOf(ledger, uid);
  if (!side) fail("permission-denied", "Bu defterin tarafı değilsiniz.");
  if (ledger.status !== "active") {
    fail("failed-precondition", "Defter kapalı.");
  }
  return {ledger, side};
}
