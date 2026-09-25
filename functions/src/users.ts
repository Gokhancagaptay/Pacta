import {HttpsError, onCall} from "firebase-functions/v2/https";
import {admin, db, REGION} from "./common/firebase";

/**
 * E-postası doğrulanmış ve profili olan kullanıcıyı bulur.
 *
 * users koleksiyonu istemciye listelenmez; kişi ekleme ve borç oluşturma
 * bu fonksiyonla Firebase Auth kaydına göre eşleşir. Profil e-postası
 * değiştirilerek başka birinin yerine geçilemez.
 */
export const lookupUserByEmail = onCall<{email?: unknown}>(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Giriş yapmalısınız.");
    }
    const raw = request.data?.email;
    const email = typeof raw === "string" ? raw.trim().toLowerCase() : "";
    if (!email || email.length > 254 || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "Geçerli bir e-posta girin.");
    }

    let user: admin.auth.UserRecord;
    try {
      user = await admin.auth().getUserByEmail(email);
    } catch (error) {
      if ((error as {code?: string}).code === "auth/user-not-found") {
        return {found: false};
      }
      throw error;
    }
    if (!user.emailVerified) return {found: false};

    const profile = await db.collection("users").doc(user.uid).get();
    if (!profile.exists) return {found: false};

    return {
      found: true,
      uid: user.uid,
      email: user.email ?? email,
      adSoyad: profile.get("adSoyad") ?? user.displayName ?? "",
    };
  }
);
