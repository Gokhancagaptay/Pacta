# Mağaza veri beyanları (taslak)

Google Play "Veri güvenliği" formu ve Apple "App Privacy" için, uygulamanın
2026-09-27 hâline göre hazırlanmıştır. Uygulamaya yeni bir SDK ya da veri türü
eklenirse bu dosya ve [gizlilik sayfası](../../web/gizlilik/index.html) birlikte
güncellenir.

## Yüklemeden önce

- [ ] Gizlilik, koşullar ve hesap silme sayfalarındaki `[...]` alanları dolduruldu,
      hukukçu onayladı, `TASLAK` kutuları, ⚖️ notları ve `noindex` kaldırıldı.
- [ ] Hosting yayında (`firebase deploy --only hosting`); şu adresler açılıyor:
  - Gizlilik politikası: `https://pacta-76686.web.app/gizlilik/`
  - Hesap silme: `https://pacta-76686.web.app/hesap-sil/`
- [ ] `assetlinks.json` içinden debug parmak izi çıkarıldı, Play App Signing
      parmak izi eklendi.

## Google Play — Veri güvenliği

| Soru | Cevap |
|---|---|
| Uygulama zorunlu kullanıcı verisi topluyor ya da paylaşıyor mu? | Evet |
| Veriler aktarım sırasında şifreleniyor mu? | Evet |
| Kullanıcı verilerinin silinmesini isteyebilir mi? | Evet — uygulama içinden ve `/hesap-sil/` sayfasından |
| Hesap silme URL'si | `https://pacta-76686.web.app/hesap-sil/` |
| Veri paylaşımı (üçüncü taraflara aktarım) | Yok. Google (Firebase) hizmet sağlayıcısıdır; karşı tarafın gördükleri kullanıcının kendi başlattığı paylaşımdır. |

Toplanan veri türleri (hiçbiri paylaşılmıyor, hiçbiri isteğe bağlı değil):

| Kategori → tür | Amaç |
|---|---|
| Kişisel bilgiler → Ad | Uygulama işlevselliği, Hesap yönetimi |
| Kişisel bilgiler → E-posta adresi | Uygulama işlevselliği, Hesap yönetimi |
| Kişisel bilgiler → Kullanıcı kimlikleri | Uygulama işlevselliği, Hesap yönetimi, Dolandırıcılığı önleme/güvenlik |
| Finansal bilgiler → Diğer finansal bilgiler (borç/alacak kayıtları) | Uygulama işlevselliği |
| Uygulama etkinliği → Kullanıcı tarafından oluşturulan diğer içerikler (açıklamalar, özel defter adları) | Uygulama işlevselliği |
| Uygulama bilgileri ve performansı → Kilitlenme günlükleri | Uygulama işlevselliği, Analiz |
| Cihaz veya diğer kimlikler (bildirim anahtarı, Crashlytics kurulum kimliği) | Uygulama işlevselliği |

**Web onay sayfası (`/o/…`, 2026-09-29 eklendi).** Uygulamayı kullanmayan
karşı taraf, özel defterdeki bir kaydı web'de onaylar. Bu kişi uygulama
kullanıcısı değildir; Play formu uygulama kullanıcılarını kapsar, ama gizlilik
politikası ve KVKK aydınlatma metni şunları anlatmalıdır ⚖️:

| Veri | Neden | Ne kadar süre |
|---|---|---|
| Karşı tarafın e-posta adresi (tam hâli sunucuda, kayıt sahibine gizlenmiş hâli) | Yanıtın o kişiye ait olduğunun kanıtı | Kayıt, özel defter ya da sahibin hesabı silinene kadar |
| IP adresi, tarayıcı bilgisi (user-agent), yanıt zamanı | Kanıt, kötüye kullanımı önleme | Aynı |
| Geçici giriş kaydı (Firebase Auth, e-posta bağlantısıyla) | E-posta doğrulaması | Yanıttan hemen sonra; yanıt yoksa 1 gün içinde silinir |
| Yanıtlanmayan onay isteği | Link çalışsın diye | Süresi dolduktan 30 gün sonra silinir |

Toplanmayanlar: konum, kişiler (rehber), fotoğraf/video, sesli kayıt, takvim,
web geçmişi, reklam kimliği, ödeme bilgisi, kredi puanı. Kamera QR okumak için
kullanılır; görüntü cihazdan çıkmaz, "toplanan veri" sayılmaz.

**Finansal özellikler beyanı:** Uygulama kredi vermez, ödeme/para transferi
yapmaz, para tutmaz; yalnızca kişiler arası kayıt tutar. Formda kredi ya da ödeme
seçenekleri işaretlenmez. Seçeneklere göre uygun kategori yükleme sırasında
yeniden kontrol edilmeli.

## Apple — App Privacy (iOS yayını için)

| Veri | Kullanıcıya bağlı mı | Amaç | Takip |
|---|---|---|---|
| Contact Info → Name, Email Address | Evet | App Functionality | Hayır |
| Financial Info → Other Financial Info | Evet | App Functionality | Hayır |
| User Content → Other User Content | Evet | App Functionality | Hayır |
| Identifiers → User ID | Evet | App Functionality | Hayır |
| Identifiers → Device ID (Crashlytics) | Hayır | App Functionality | Hayır |
| Diagnostics → Crash Data | Hayır | App Functionality | Hayır |

iOS için ayrıca: privacy manifest (`PrivacyInfo.xcprivacy`), Apple ile giriş.

## Veri envanteri (kaynak kodda nerede?)

| Veri | Yer | Saklama |
|---|---|---|
| Profil, tercihler, Pacta kodu | `users/{uid}`, `publicProfiles/{uid}` (yalnızca ad), `codes/{kod}` | Hesap silinince |
| Bildirimler, gelen kutusu | `users/{uid}/notifications`, `users/{uid}/inbox` | Hesap silinince |
| Defterler ve kayıtlar | `ledgers/{id}` (+ `entries`, `events`) | Ortak: kapanıştan 10 yıl (`dailyMaintenance`); özel: silinince |
| Silme işareti | `deletedAccounts/{uid}` | 10 yıl (`dailyMaintenance`) |
| Doğrulanmamış hesaplar | Firebase Authentication | 30 gün (`dailyMaintenance`) |
| Bekleyen push, günlük sayaçlar | `pushQueue`, `rateLimits` | Gönderilince / hesapla |
| Çökme raporları | Firebase Crashlytics | 90 gün |
| Sunucu kayıtları | Cloud Logging | 30 gün |

E-postayla gelen silme talepleri: `functions/scripts/deleteAccount.js`.
