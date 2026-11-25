# Pacta — devir notu (yeni ajan için)

Son güncelleme: 2026-11-25. Dal: `faz-3-hesap-silme` (push'lu). `main`'e birleştirme PR'ı açıldı.
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
| Sunucu | Cloud Functions v2, Node 22, TypeScript, zod. Bölge **`us-central1`** (veritabanıyla aynı) |
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

- **Canlıda:** 2026-11-24 kurulumu (commit `32b1c55`): firestore kuralları ve dizinleri, 24 fonksiyon (`us-central1`), statik hosting. Bu daldaki her şey canlıda: Faz 2c web onayı, denetim düzeltmeleri A–G, bölge taşıma.
- `europe-west1`'deki 17 eski fonksiyon silindi. 2026-11-24 öncesi derlenmiş uygulama çalışmaz (eski bölgeyi arar).
- Konsol ayarları yapıldı: "Email link (passwordless sign-in)" açık, herkese görünen proje adı "Pacta".
- Yasal sayfalar (`/gizlilik`, `/kosullar`, `/hesap-sil`) bilerek yayın dışı; 404 döner.
- Kurulum öncesi doğrulama (aynı gün): biçim ve analiz temiz, Flutter 93, sunucu 107, kural 24 test geçti.

### Zorunlu güncelleme

- Uygulama `config/app` belgesindeki `minBuild` değerini okur (`lib/app/update_gate.dart`). Değer uygulamanın derleme numarasından (`AppConstants.buildNumber`) büyükse "Güncelleme gerekli" ekranı açılır ve başka hiçbir ekrana geçilemez.
- Belge yoksa ya da okunamazsa uygulama engellenmez. Belge şu an **yok**; gerektiğinde Firebase Console → Firestore → `config/app` → `minBuild` (sayı) olarak eklenir.
- Kullanım: sunucuda eski uygulamayı kıracak bir değişiklik kurulmadan önce yeni sürüm mağazada yayınlanır, sonra `minBuild` yükseltilir.
- Her yeni sürümde `pubspec.yaml` içindeki `+N` ile `AppConstants.buildNumber` birlikte artırılır; ikisi farklıysa test düşer.
- Bu kontrol 2026-11-24 sonrası derlemelerde vardır; daha eski kurulu sürümler ekranı göstermez.

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
| e790e75 | **Cihaz testi bulguları (24 Kasım):** bekleyen düzeltme metni, "Kimden" etiketi, geçmişte olay sırası |
| 013a631 | **Zorunlu güncelleme:** `config/app.minBuild`, güncelleme ekranı, kural (bkz. bölüm 6) |
| 05243b5 | **Belirli bir borca ödeme:** kayıt detayından borca bağlı ödeme (`linkedEntryId`), açık tutar hazır gelir |
| 650cab0 | **Kayıt arama:** defter sayfasında açıklama, tutar, durum araması; ek okuma yok (kayıtlar zaten yüklü) |
| 3b8bc09 | **Çevrimdışı göstergesi:** ana kabukta şerit (`offline_banner.dart`), tek ve açık bağlantı hatası mesajı |
| a8f1a65 | **Bildirim silme ve saklama:** kaydırarak silme ("Geri al" 4 sn), tümünü sil, günlük bakımda 90 gün (`NOTIFICATION_DAYS`); kural, dizin ve `dailyMaintenance` kurulumu gerekir |
| 7ee60cc | **Tarih aralıklı ekstre:** PDF/CSV için dönem seçimi; devreden bakiye, dönem hareketi, dönem sonu bakiye (`statement_period.dart`) |
| c040451 | **Kayıt ekleme:** gönder düğmesi klavyenin üstünde kalır |
| 7f08977 | **Tutarlılık denetimi:** salt okunur bakiye, sıra, zincir ve düzeltme bağlantısı denetimi (`audit.ts`); gece bakımında son 26 saatte değişen defterler; `functions/scripts/auditLedgers.js` |
| 1d1e352 | **Hatırlatma:** istek kimliğiyle tekrar denemede çift gönderim yok; 2 dakikadan kısa bekleyecek push kuyruğa alınmaz (`PUSH_QUEUE_MARGIN_MS`) |
| bb4e9f1 | **AuthService** uygulama boyunca tek örnek |
| 5dcf600 | **Verilerimi indir (KVKK):** Profil > Hesap; uygulamanın okuyabildiği tüm veri tek JSON; dosyada olmayanlar ve nedenleri yazılı |

**Test sayıları:** sunucu 139, kural 26, Flutter 171. Son CI yeşil.

### Tutarlılık denetimi

- Gece bakımı yalnızca o gün değişen defterlere bakar (gece başına en fazla 500 defter, 50.000 kayıt). Sorun bulursa günlüğe `[audit] Defterde tutarsızlık` hatası yazar; kimseye bildirim gitmez. Cloud Logging'de `[audit]` içeren hatalara uyarı kurulabilir (Console adımı).
- Elle düzenleme ya da yalnızca itiraz/düzenleme içeren günler gece denetiminde görünmez. Hepsini taramak için: `functions/` içinde `npm run build`, yönetici kimliğiyle `node scripts/auditLedgers.js --hepsi` (tek defter için defter kimliği). Betik yalnızca okur.
- Eylül'deki eski komut sürümleriyle yazılmış veriler hiç denetlenmedi; ilk tam taramada sorun çıkabilir.

## 7b. Dallar ve canlıya kurulum bekleyenler (25 Kasım)

- **`faz-3-hesap-silme`** (25 Kasım, `main`'e PR açık): `gece-calismasi` + `gecis-paketler` (paket geçişi, Gradle 9, sunucu paketleri) + `oneri-toplu-onay` hızlı ileri birleştirildi. Telefonda Google ile giriş ve push (arka planda bildirim, dokununca doğru kayıt) doğrulandı. Derleme numarası 3.

- Yan dallar (`gece-calismasi`, `gecis-paketler`, `deneme-*`, `oneri-toplu-onay`) faz-3'e alındı; silinebilir.
- `gece-calismasi` (faz-3 üstünde, push'lu, CI yeşil): hatırlatma tekrar denemesi ve sabah push gecikmesi (`1d1e352`), `AuthService` tek örnek, Verilerimi indir (KVKK), Profil tema satırı, gizlilik taslağı düzeltmeleri, belge güncellemeleri. Uygun bulunursa faz-3'e hızlı ileri birleşir.
- `deneme-bagimliliklar` (gece-calismasi üstünde; `gecis-paketler`'e alındı): `firebase-functions` 7.4, `firebase-admin` 13.10. Kod değişmedi; lint, 139 sunucu + 26 kural testi ve kurulumun kuru çalıştırması temiz. `firebase-admin` 14 ad alanlı yazımı (`admin.firestore()`) kaldırdığı için 13'te kalındı.
- `deneme-gradle9` (gece-calismasi üstünde; `gecis-paketler`'e alındı ve tam yerleşik Kotlin'e geçildi): AGP 9.0.1 + Gradle 9.1.0, geçici köprü (`android.builtInKotlin=false`, `android.newDsl=false`, `kotlin-android` duruyor). Debug ve imzalı release APK derlendi; Flutter'ın "yakında desteklenmeyecek" uyarıları kalktı. Tam geçiş için `cloud_functions`, `share_plus`, `shared_preferences_android` eklentilerinin yerleşik Kotlin destekli sürümleri gerekir.
- **Canlıya kurulmayı bekleyen** (her biri kullanıcı onayıyla):
  - `dailyMaintenance`: tutarlılık denetimi aşaması (`7f08977`).
  - `sendReminder` ve `onNotificationCreated`: `gece-calismasi` alınırsa (`1d1e352`).
  - `gecis-paketler` alınırsa bütün fonksiyonlar (sunucu paketleri değişti).
- **Mağaza kontrolü:** release APK'daki yerel kütüphanelerin hepsi 16 KB sayfa boyutuna hizalı (ELF yükleme bölümleri 0x4000 ya da 0x10000, `zipalign -P 16` temiz). Play'in Android 15 şartı karşılanıyor.
### Paket geçişi (`gecis-paketler`, 25 Kasım)

- **Yükseltilenler:** FlutterFire (core 5, auth 7, firestore 7, functions 7, messaging 17, crashlytics 6), `share_plus` 13, `shared_preferences_android` 2.5, `google_sign_in` 7, AGP 9.0.1, Gradle 9.1.0. Sunucu: `firebase-functions` 7.4, `firebase-admin` 13.10.
- **Android derlemesi yerleşik Kotlin'le:** `android.builtInKotlin=true`, `kotlin-android` eklentisi yok; hiçbir eklenti KGP uygulamıyor. `android.newDsl=false` duruyor (Flutter'ın yeni DSL desteği gelince kaldırılacak).
- **Google ile giriş:** `google_sign_in` 7 Credential Manager kullanır. `AuthService._google()` bir kez `initialize()` eder; kimlik yalnızca `idToken` ile alınır. İstemci kimlikleri `google-services.json` içindeki web istemcisinden okunur. Firebase'de yükleme anahtarı (SHA-1 `a7e378…`) ve debug anahtarı kayıtlı; Play App Signing açılınca onun SHA-1'i de eklenmeli, yoksa mağazadan inen sürümde Google ile giriş çalışmaz.
- **Bilerek yükseltilmeyenler:** Riverpod 3 ve `google_fonts` 9 (yalnız kod değişikliği, kazanç yok), `flutter_local_notifications` 23 (compileSdk 37 ve AGP 9.1.1 ister; KGP sorunu yok), `flutter_lints` 6.
- **Push token'ı (FID) ertelendi:** `firebase_messaging` 17, `getToken`/`onTokenRefresh`/`deleteToken`'ı kullanımdan kaldırdı; yeni `register()`/`onRegistered` FCM token'ı değil Firebase Installation ID (FID) verir. Firebase'e göre iki yol da şu an tam destekli, token'lar için kapanış tarihi açıklanmadı; geçiş döneminde sunucunun `token` alanı FID'leri de kabul ediyor. Tam geçiş için: Android manifest'e `firebase_messaging_installation_id_enabled=true`, istemcide `onRegistered`, sunucuda `fid`/`fids` (kurulu `firebase-admin` 13.10'da `fids` yok; 14 ise `admin.firestore()` gibi ad alanlı yazımı kaldırıyor, sunucu kodu modüler içe aktarmaya geçmeli). İki API birlikte kullanılmamalı (Firebase uyarısı). Ayrı iş olarak, telefonda push testiyle yapılmalı.

## 8. Yapılacaklar (öncelik sırasıyla)

1. **Canlıya kurulum:** `main`'e birleşince bütün fonksiyonlar (sunucu paketleri, gece denetimi, hatırlatma düzeltmesi), kullanıcı onayıyla.
2. **Kalan cihaz testleri:** `docs/test-listesi.md`, özellikle 7b (web onayı gerçek e-postayla; henüz hiç denenmedi), uygulama kilidi, QR, yeni hesapla kayıt, hesap silme.
3. **Google Play:** kullanıcı geliştirici hesabı açınca:
   - Yeni kişisel hesaplar için en az 12 kişilik kapalı test, 14 gün kesintisiz.
   - `assetlinks.json`'dan debug parmak izini çıkar, Play App Signing parmak izini ekle.
   - App Check'i aç (Play Integrity).
   - Yasal metinleri hukukçuya onaylat; `hosting/gizlilik|kosullar|hesap-sil` sayfalarını doldur, `firebase.json` ignore listesinden çıkar.
   - `/u` davet sayfasına mağaza bağlantısı ekle.
   - Veri beyanlarını tamamla (`docs/magaza/veri-beyanlari.md`).
4. **Eski v1 verisi:** canlıda `debts` ve kök `notifications` koleksiyonlarında belge var mı, kullanıcı Console'dan baksın. Varsa tek seferlik temizlik betiği yazılacak; çalıştırmadan önce sorulacak.
5. **Bilerek bırakılan düşük önemli maddeler:**
   - Gelen kutusu belge kimliği `entryId`. Çakışma pratikte yok: istemci kimlikleri Firestore'un 20 karakterlik rastgele kimliği, taşıma kimlikleri `t_<defter>_<sıra>` biçiminde defter kimliğini içerir. Geçiş gerekmez.
   - `createLedger` ve `convertPrivateLedger` günlük sınırı ana işlemden önce ayrı düşer. Bu bilerek: başarısız kişi aramaları da sayılır, e-postayla kullanıcı taraması sınırlanır. Değiştirmeyin.
   - (Çözüldü: hatırlatma tekrar denemesi ve 09:00 push gecikmesi `1d1e352`; `AuthService` tek örnek `bb4e9f1`.)
6. **Özellikler** (sırayı kullanıcı belirleyecek):
   - Ek dosya.
   - Gelen kutusunda toplu onay.
   - Çevrimdışı şeridinin bekleme süreleri (8/3/2 sn) gerçek cihazda uçak moduyla denenip gerekirse ayarlanacak.
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
