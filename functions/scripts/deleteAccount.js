// E-postayla (ya da web'deki /hesap-sil sayfası üzerinden) gelen hesap
// silme taleplerini işler. Uygulamadaki "Hesabı sil" ile aynı işi yapar:
// kişisel veriler silinir, ortak geçmiş karşı tarafta "Silinmiş kullanıcı"
// olarak kalır.
//
// Talebi göndereni doğrulamadan çalıştırmayın: talep, hesabın e-posta
// adresinden gelmeli (ya da o adrese gönderilen onay yanıtlanmalı).
//
// Kullanım (functions klasöründe):
//   npm run build
//   gcloud auth application-default login
//   $env:GCLOUD_PROJECT="pacta-76686"            (PowerShell)
//   node scripts/deleteAccount.js kisi@example.com          -> önizleme
//   node scripts/deleteAccount.js kisi@example.com --sil    -> siler
//
// Hizmet hesabı anahtarı kullanılacaksa GOOGLE_APPLICATION_CREDENTIALS
// ile verin; anahtar dosyasını asla depoya koymayın.

const {admin, db} = require("../lib/common/firebase.js");
const {removeAccount} = require("../lib/ledger/account.js");

async function main() {
  const [email, flag] = process.argv.slice(2);
  if (!email || (flag && flag !== "--sil")) {
    console.error("Kullanım: node scripts/deleteAccount.js <e-posta> [--sil]");
    process.exit(2);
  }
  let user;
  try {
    user = await admin.auth().getUserByEmail(email.trim().toLowerCase());
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      console.log("Bu e-postayla kayıtlı hesap yok.");
      return;
    }
    throw error;
  }
  const ledgers = await db.collection("ledgers")
    .where("memberUids", "array-contains", user.uid).get();
  const shared = ledgers.docs.filter((d) => d.get("mode") !== "private");
  console.log({
    uid: user.uid,
    email: user.email,
    girisYontemleri: user.providerData.map((p) => p.providerId),
    olusturma: user.metadata.creationTime,
    sonGiris: user.metadata.lastSignInTime,
    ozelDefter: ledgers.size - shared.length,
    ortakDefter: shared.length,
  });
  if (flag !== "--sil") {
    console.log("Önizleme. Silmek için komutu --sil ile tekrar çalıştırın.");
    return;
  }
  const summary = await removeAccount(user.uid, "request");
  console.log("Silindi:", summary);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
