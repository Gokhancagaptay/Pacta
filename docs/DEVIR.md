# Pacta — devir notu (yeni ajan için)

Son güncelleme: 2026-09-30. Dal: `faz-3-hesap-silme` (son commit `3299161`, push'lu). `main` henüz birleştirilmedi.
Bu dosya projeyi hızlıca devralmak içindir: ne var, nasıl çalışılır, ne yapıldı, ne kaldı.

---

## 1. Ürün tek paragrafta

Pacta, iki kişinin **karşılıklı onayla** tuttuğu borç–alacak defteri (önce bireysel, sonra KOBİ).

- Bir kişinin **lehine** girilen kayıt, karşı taraf onaylamadan bakiyeye işlenmez.
- Girenin **aleyhine** olan kayıt (ör. alacaklının "ödeme aldım" kaydı) hemen işlenir.
- Onaylı kayıt değiştirilemez; düzeltme **ters kayıtla** yapılır.
- Uygulaması olmayan kişi için **özel defter** tutulur. Bu defter sonradan ortak deftere taşınabilir; karşı taraf özel defterdeki kaydı web linkiyle de onaylayabilir.
- Birimler karışmaz: TRY, USD, EUR, gram altın (GAU), çeyrek (CEYREK) ayrı bakiyelerde tutulur.
- Tutarlar tamsayı küçük birimdedir (kuruş, miligram, adet); `double` kullanılmaz.

## 2. Teknoloji ve yerler

| Katman | Ayrıntı |
|---|---|
| Uygulama | Flutter 3.47 (Dart 3.13, SDK kısıtı `^3.13.0`), Riverpod 2.6, Material 3; paket `app.pacta.mobile` |
| Sunucu | Cloud Functions v2, Node 22, TypeScript, zod. Bölge **`us-central1`** (kodda; canlıda hâlâ `europe-west1`, sonraki kurulumda taşınır) |
| Veri | Firestore `nam5` (ABD). İstemci defterlere **yazamaz**; tüm durum geçişleri callable fonksiyonlarla yapılır |
| Kimlik | Firebase Auth: e-posta+şifre (doğrulama zorunlu), Google. Web onayında e-posta bağlantısıyla giriş |
| Bildirim | FCM (cihaz başına anahtar) + `users/{uid}/notifications` |
| Hosting | `hosting/` klasörü statik yayınlanır (Flutter web **yayınlanmaz**) |
| Proje | Firebase `pacta-76686`; repo `github.com/Gokhancagaptay/Pacta` |

## 3. Kod haritası

```
lib/
  app/            theme.dart, app_lock.dart (kilit + FLAG_SECURE), navigation.dart (kök navigatorKey),
                  startup.dart (Crashlytics/push/link servisleri, bir kez)
  core/           money (Money, Asset), dates (LocalDate), text (trLower), ui/widgets.dart,
                  report.dart (reportError → Crashlytics), legal.dart
  features/ledger/
    domain/       models.dart (Ledger, LedgerEntry, WebConfirmation...), entry_text.dart (tüm durum metinleri),
                  summary.dart, statement.dart (CSV), people_summary.dart, reminder.dart, transfer_plan.dart
    data/         ledger_repository.dart (tüm callable çağrıları + akışlar; parseEach, commandMessage), statement_pdf.dart
    application/  providers.dart (Totals, currentUid, ...)
    presentation/ home_shell, home_page, people_page, ledger_page, entry_detail_page, entry_composer_page,
                  activity_page, notifications_page, add_person_sheet, contacts_ui, convert_ledger_page, statement_export
  features/profile/ profile_page, delete_account_page
  screens/auth, screens/settings, services/ (auth_service, firestore_service, push_notification_service,
                  notification_routes, app_link_service)
  auth_wrapper.dart  hangi ekran açılacağına tek başına karar verir (giriş/doğrulama/koşullar/ana ekran)

functions/src/
  common/         firebase.ts (REGION), push.ts (çoklu cihaz, ölü anahtar temizliği), queries.ts (deleteQuery)
  ledger/
    callable.ts   requireUid (profil + koşul + silinmiş + misafir kontrolü), readLedger, assertNotBlocked,
                  consumeDaily / readDailyInTx+useDailyInTx
    commands.ts   createLedger, createEntry, confirm/dispute/reject/revise/cancel/reverseEntry, convertPrivateLedger
    contacts.ts   Pacta kodu, previewCode (kod ya da e-posta), deletePrivateLedger, setBlocked
    web.ts        uygulamasız web onayı (request/open/respondWebConfirmation, misafir temizliği)
    devices.ts    registerPushToken (anahtar tek sahipli, hesap başına 5 cihaz)
    notify.ts     deliver (yalnız bildirim belgesi yazar) + onNotificationCreated (push'u gönderir)
    profile.ts    onUserProfileWritten (ad değişikliği defterlere yansır)
    due.ts        onLedgerEntryWritten (vade özeti; retry açık)
    reminders.ts  sendReminder, dailyReminders (09:00 TRT)
    account.ts    deleteAccount/removeAccount (silme işareti pending → tamamlanınca false)
    maintenance.ts dailyMaintenance 04:00: yarım silmeleri tamamlar, doğrulanmamış hesaplar, 10 yıllık saklama, web temizliği
  functions/test/*.test.js  emulator testleri (helpers.js: kullanıcılar ali/ayse/mallory, profile() koşul kabullü)
firestore.rules, firestore.indexes.json (fieldOverrides: büyük alanlar dizinsiz)
firestore-tests/  kural testleri + fonksiyon testlerini çalıştıran betikler
hosting/          index (tanıtım), 404, u/ (davet), o/ (web onayı), auth/continue, .well-known/assetlinks.json,
                  gizlilik|kosullar|hesap-sil (TASLAK, firebase.json ignore ile yayın dışı)
web/              yalnız Flutter web derlemesi için; yayınlanmaz
docs/test-listesi.md   cihaz test listesi (⭐ = kritik)
docs/magaza/veri-beyanlari.md  Play/Apple veri beyanları taslağı
contracts/        Dart–TS ortak birim tanımları ve hash test vektörleri
```

## 4. Değişmez kurallar (bozma)

- **Durum geçişleri yalnızca sunucuda** yapılır. `ledgers/**` istemciye salt okunurdur.
- **`requireUid`** her komutta şunları ister: doğrulanmış e-posta (ya da telefon), `users/{uid}` belgesi, `termsAcceptedAt`, silme işaretinin olmaması, web misafiri olmaması.
- **Üye olmayan** bir defter için her zaman `not-found` döner (ilişki sızmasın).
- Transaction içinde bildirim listesini callback başında sıfırla (`notices.length = 0`). Yoksa transaction yeniden denendiğinde çift bildirim gider.
- Transaction'da **önce okumalar, sonra yazmalar**. Günlük sınır için `readDailyInTx` (okuma) ve `useDailyInTx` (yazmadan hemen önce) kullanılır.
- Kayıt yazımı `tx.create` ile yapılır (ezme yok). İstemci kimliği `t_` ile başlayamaz; bu önek taşıma kayıtlarına ayrılmıştır.
- Engellenen taraf (`ledgers/{id}.blockedBy.{side}`) kayıt, düzeltme ve hatırlatma gönderemez.
- Metin terimleri:
  - Bekleyen kaydı değiştirmek "**Düzenle / Düzenlendi**".
  - Onaylı kaydı ters kayıtla geri almak "**Düzelt / Düzeltildi**".
  - "Senet, ibraname, kefil, icra" kelimeleri kullanılmaz.
- Kilit ekranında ve push'ta **tutar** gösterilmez (hatırlatmalar).

## 5. Çalışma komutları (Windows)

- **Flutter:** `flutter analyze`, `flutter test`, `dart format --set-exit-if-changed lib test`.
  - CI bunlara ek olarak `flutter build apk --debug` çalıştırır.
  - Testlerde `FakeRepo` kullanılır (`test/v2_screens_test.dart`) ve `PactaTheme.useGoogleFonts = false` yapılır.
- **Fonksiyon testleri:** `firestore-tests/` içinde `JAVA_HOME=$HOME/.jdks/jdk-21.0.12.1+1` ayarlanır.
  - `npm run functions:test`: derler ve testleri sırayla çalıştırır.
  - `npm run emulator:test`: kural testleri.
- **Lint:** `cd functions && npx eslint --ext .js,.ts src test`. En fazla 80 karakter; JSDoc zorunlu.
- **Kurulum (her seferinde kullanıcıya SOR):** `firestore-tests/` içinden:
  `npx firebase deploy --only firestore,functions,hosting --project pacta-76686 --force --non-interactive`
  - Önce `--dry-run` ile doğrula.
  - `npm run build` çalışmadan önce `lib` temizlenir (prebuild).
- **CI kontrolü:** `gh` kurulu değil. Bunun yerine: `curl -s "https://api.github.com/repos/Gokhancagaptay/Pacta/actions/runs?branch=<dal>&per_page=3"`
- **Windows tuzakları:**
  - PowerShell `git commit -m` içindeki tırnakları bozar; mesajı dosyaya yazıp `git commit -F dosya` kullan.
  - Bash heredoc içindeki `\'` ve `\t` bozulur. Karmaşık düzenlemede Python betiği yaz; dosyaları `newline='\n'` ile kaydet.
- **Git kuralı:** commit'lerde ve PR'larda **AI imzası/co-author YOK**; yazar yalnızca Gokhancagaptay. Her anlamlı adımda commit'le ve push'la.
- **Sırlar:** yükleme anahtarı `C:\Users\cagap\.pacta-keys\`; şifre `android/key.properties` içinde (git'e girmez). Asla yazdırma.

## 6. Canlıdaki durum

- **Canlıda:** 2026-09-28 kurulumu (commit `5eb44bc`). Fonksiyonlar `europe-west1`'de, 17 adet. Hosting en son 2026-09-26'da, eski Flutter web ile kuruldu.
- **Canlıda OLMAYAN** (bu daldaki her şey): Faz 2c web onayı, denetim düzeltmeleri A–G, bölge taşıma, statik hosting.
- Kuru çalıştırma (`--dry-run --force`) 2026-09-29'da temiz geçti. Kurulum 7 yeni fonksiyon ekleyecek. Bölge değiştiği için europe-west1'deki eski fonksiyonlar `--force` ile silinecek.
- **Kurulumdan önce kullanıcının yapması gereken:** Firebase Console → Authentication → Email/Password bölümünde "Email link (passwordless sign-in)" açılmalı ve herkese görünen proje adı "Pacta" yapılmalı.
- **Kurulumdan hemen sonra** telefona yeni APK kurulmalı (`flutter build apk --release`). Eski uygulama yeni bölgeye ulaşamaz ve koşul kontrolüne takılır.

## 7. Bu dalda yapılanlar (özet)

| Commit | İçerik |
|---|---|
| 07de5cd, 14dcc78, 870663b | **Faz 2c web onayı:** özel defter kaydı için `/o/<token>` linki; karşı taraf e-posta bağlantısıyla doğrular; onay/itiraz/ret; kayıtta `webConfirmation`; misafir Auth hesabı yanıttan sonra silinir |
| 6459a67, e05a107 | **Paket A:** taşımada kayıt ezme, ters kayıt sınırı, çift bildirim, vade fırtınası, not-found eşitliği, tekrar denenen komutlar, **engelleme** |
| ed6b423 | **Paket B:** requireUid profil, koşul ve misafir kontrolü; sunucu tarafı IP; **isteğe bağlı alıcı e-postası**; `/o` güvenlik başlıkları |
| ebc149b, dca4379 | **Paket C:** `Money.parse` ("0.500"), CSV formül koruması, onaylı bakiye (özel/kapalı ayrı), bozuk belge dayanıklılığı, yanlış sayfa kapanması, çift gönderim, Türkçe hatalar |
| a3cf28f, cd040c7 | **Paket D:** cihaz başına tek sahipli push anahtarı; çıkışta sayfa yığını ve önbellek temizliği; kilit (FLAG_SECURE, cihaz kilidi yoksa kapanma); yedekleme kapalı; pazarlama izni varsayılan kapalı |
| 4be3f2f | E-postayla taşımada önce kişinin adı; bağlı ödeme doğrulaması; ters kayıt kimliği kontrolü |
| 3c22c21, c98245a, b602766 | **Paket E (kullanıcı deneyimi):** işlem tarihine göre sıralama, sayfalama, işlem tarihi seçimi, "Düzenle" terimi, TL dışı bakiye satırı, büyük yazı ve ekran okuyucu, CSV etki sütunu, davet/gizlenenler, profil uid hatası, bildirim izni zamanlaması, başka cihazda silinen hesap |
| 43efb26 | **G hataları:** ad değişikliği defterlere yansır, yarım silme tamamlanır, telefonla doğrulanmış hesap korunur, vade tetikleyicisi yeniden dener |
| 507e8e8, 0bd17ca, 8fb304d | **Paket F:** dizin muafiyetleri, getAll, ortak yardımcılar, ölü kod temizliği, SDK 3.13, CI (biçim kontrolü + APK), statik `hosting/` |
| 3299161 | **Hız:** `us-central1`, push tetikleyiciyle arka planda, günlük sınır ana transaction'da, **anlık çıkış** |

**Test sayıları:** sunucu 107, kural 24, Flutter 93. Son CI yeşil.

## 8. Yapılacaklar (öncelik sırasıyla)

1. **Kurulum** (kullanıcı onayı ve konsol ayarından sonra) → yeni APK → `docs/test-listesi.md` üzerinden cihaz testi, özellikle 7b (web onayı) uçtan uca. Web onay sayfası gerçek e-postayla henüz hiç denenmedi.
2. Cihaz testinden gelen hataları düzelt → `faz-3-hesap-silme` dalını `main`'e PR ile birleştir (AI imzası yok).
3. **Google Play:** kullanıcı geliştirici hesabı açınca:
   - Yeni kişisel hesaplar için en az 12 kişilik kapalı test, 14 gün kesintisiz.
   - `assetlinks.json`'dan debug parmak izini çıkar, Play App Signing parmak izini ekle.
   - App Check'i aç (Play Integrity).
   - Yasal metinleri hukukçuya onaylat; `hosting/gizlilik|kosullar|hesap-sil` sayfalarını doldur, `firebase.json` ignore listesinden çıkar.
   - `/u` davet sayfasına mağaza bağlantısı ekle.
   - Veri beyanlarını tamamla (`docs/magaza/veri-beyanlari.md`).
4. **Eski v1 verisi:** canlıda `debts` ve kök `notifications` koleksiyonlarında belge var mı, kullanıcı Console'dan baksın. Varsa tek seferlik temizlik betiği yazılacak; çalıştırmadan önce sorulacak.
5. **Bilerek bırakılan düşük önemli maddeler:**
   - `sendReminder` tekrar denenince "yakın zamanda gönderildi" diyor (idempotency anahtarı yok).
   - Gelen kutusu belge kimliği `entryId`; defterler arasında teorik çakışma var (`ledgerId_entryId` olmalı; geçiş gerekir).
   - `createLedger` ve `convertPrivateLedger` hâlâ ayrı `consumeDaily` kullanıyor.
   - 09:00'dan hemen önce kuyruğa düşen push bir gün gecikebilir.
   - `AuthService` her çağrıda yeniden oluşturuluyor (tekil sağlayıcı olabilir).
6. **Özellikler** (sırayı kullanıcı belirleyecek):
   - Kayıt arama; belirli bir borca ödeme arayüzü (sunucu `linkedEntryId`'yi destekliyor, uygulama göndermiyor).
   - Ek dosya; tarih aralıklı ekstre.
   - Bildirim silme ve saklama süresi (TTL); gelen kutusunda toplu onay.
   - KVKK veri dışa aktarma; bakiye ve zincir tutarlılık denetimi.
   - Çevrimdışı göstergesi, zorunlu güncelleme kontrolü.
   - SMS OTP (web onayının güçlü sürümü) ve rehberden kişi seçici.
   - iOS: entitlements, AASA, Google iOS istemcisi, hedef sürüm 13, Apple ile giriş, privacy manifest.
   - google_sign_in 7 + FlutterFire büyük sürüm geçişi, Gradle/AGP 9.
   - Fonksiyonları sürekli açık tutma (`minInstances`): kullanıcı "şimdilik hayır" dedi.
   - Yasal karar Avrupa'da yeni bir Firebase projesi gerektirirse bölge yeniden ele alınacak.
7. **Sonraki fazlar:** Faz 4 Plus abonelik, Faz 5 KOBİ modülü.

## 9. Kullanıcıyla çalışma

- Kullanıcı Türkçe konuşuyor; kısa ve net anlatım seviyor. Kararları sorulduğunda hızlı veriyor.
- Kurulum ve geri alınamaz işlemlerden önce **mutlaka sor**.
- Hukuki ve mağaza işleri Play hesabı açılana kadar beklemede; engel diye gündeme getirme.
- Ayrıntılı eski yol haritası repo dışında: `C:\Users\cagap\.claude\plans\uygulamamz-n-son-halini-incele-smooth-biscuit.md` (§14–§18) ve denetim planı `frolicking-booping-cake.md`. İkisi de repoya commit'lenmez.
