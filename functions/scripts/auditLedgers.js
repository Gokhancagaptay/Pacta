// Defterlerin bakiye ve zincir tutarlılığını denetler (salt okunur; hiçbir
// şey yazmaz, onarmaz). Gece bakımındaki denetimin elle çalıştırılan
// hâlidir: tek bir defter ya da tüm defterler, sınırsız pencereyle.
// Sorunlarda uyuşmayan sayılar da yazılır; çıktıyı paylaşırken dikkat.
//
// Kullanım (functions klasöründe):
//   npm run build
//   gcloud auth application-default login
//   $env:GCLOUD_PROJECT="pacta-76686"            (PowerShell)
//   node scripts/auditLedgers.js <defterId>       -> tek defter
//   node scripts/auditLedgers.js --hepsi          -> tüm defterler
//
// Sorun bulunursa çıkış kodu 1, hata olursa 2 olur. Bir defterde
// MAX_ENTRIES'tan fazla kayıt varsa o defter atlanır ve yazılır.
//
// Hizmet hesabı anahtarı kullanılacaksa GOOGLE_APPLICATION_CREDENTIALS
// ile verin; anahtar dosyasını asla depoya koymayın.

const {db} = require("../lib/common/firebase.js");
const {auditStoredLedger} = require("../lib/ledger/audit.js");

const MAX_ENTRIES = 100000;

async function main() {
  const [target, ...rest] = process.argv.slice(2);
  if (!target || rest.length > 0) {
    console.error(
      "Kullanım: node scripts/auditLedgers.js <defterId> | --hepsi");
    process.exit(2);
  }
  // listDocuments belgesi silinmiş ama alt koleksiyonu kalmış defterleri de
  // getirir (yarım kalmış silme).
  const ids = target === "--hepsi" ?
    (await db.collection("ledgers").listDocuments()).map((r) => r.id) :
    [target];

  const summary = {defter: 0, denetlenen: 0, sorunlu: 0, sorun: 0,
    atlanan: 0, bulunamayan: 0};
  const problems = [];
  for (const id of ids) {
    summary.defter++;
    const res = await auditStoredLedger(id, MAX_ENTRIES);
    if (res.status === "missing") {
      summary.bulunamayan++;
      if (ids.length === 1) console.log(`Defter bulunamadı: ${id}`);
      continue;
    }
    if (res.status === "tooLarge") {
      summary.atlanan++;
      console.log(`Atlandı (${MAX_ENTRIES} kayıttan fazla): ${id}`);
      continue;
    }
    summary.denetlenen++;
    if (res.problems.length > 0) {
      summary.sorunlu++;
      summary.sorun += res.problems.length;
      problems.push(...res.problems);
    }
  }

  console.log(summary);
  for (const p of problems) console.log(JSON.stringify(p));
  if (problems.length === 0) console.log("Tutarsızlık bulunmadı.");
  process.exitCode = problems.length > 0 ? 1 : 0;
}

main().catch((error) => {
  console.error(error);
  process.exit(2);
});
