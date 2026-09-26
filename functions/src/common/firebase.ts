import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Maliyet güvencesi: bir fonksiyon aynı anda en fazla 10 örnekle çalışır.
// Hata ya da kötüye kullanımda harcamanın üst sınırını düşürür.
setGlobalOptions({maxInstances: 10});

export {admin};
export const db = admin.firestore();
export const REGION = "europe-west1";
