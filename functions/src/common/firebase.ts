import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export {admin};
export const db = admin.firestore();
export const REGION = "europe-west1";
