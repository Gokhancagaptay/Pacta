# Pacta

İki kişinin birlikte tuttuğu, **karşılıklı onaylı** borç–alacak defteri.
Bir kişinin lehine girilen kayıt, karşı taraf onaylamadan bakiyeye işlenmez.
Onaylanmış kayıt değiştirilemez; düzeltme ters kayıtla yapılır ve geçmiş korunur.

## Özellikler

- **Ortak defter:** kişi başına tek defter, onaylı bakiye, onay bekleyenler.
- **Kayıtlar:** borç verdim / aldım, ödeme yaptım / aldım. Karşı taraf onaylar, itiraz eder ya da reddeder. Kaydı giren onaydan önce düzeltebilir ya da geri çekebilir.
- **Aleyhe kayıt:** kaydı girenin aleyhine olan kayıt (ör. alacaklının "ödeme aldım" kaydı) onay beklemeden işlenir. Uygulamayı kullanmayan kişiler için özel defter.
- **Vadeler ve hatırlatmalar:**
  - Açık vadeler ödemeler en eski borçtan düşülerek hesaplanır.
  - Uygulama içinde nazik, sınırlı hatırlatma gönderilir; bildirimde tutar yazmaz.
  - Vade günü bildirimleri otomatik gider.
- **Kişi ekleme:** e-posta, 6 karakterlik Pacta kodu, QR ya da davet linki.
- **Kişiler listesi:** favoriler, listeden kaldırma, tablo görünümü, süzgeçler ve toplamlar.
- **Hareketler:** yaklaşan vadeler ve tüm defterlerdeki son kayıtlar.
- **Birimler:** TL, dolar, euro, gram altın, çeyrek altın. Her birim ayrı bakiye olarak tutulur.

## Mimari

| Katman | Teknoloji |
|---|---|
| Uygulama | Flutter 3.47, Riverpod 2.6, Material 3 |
| Sunucu | Cloud Functions v2 (Node 22, TypeScript, zod), bölge `europe-west1` |
| Veri | Cloud Firestore; istemci defterlere yazamaz, tüm geçişler callable fonksiyonlarla yapılır |
| Kimlik | Firebase Auth (e-posta doğrulaması zorunlu, Google ile giriş) |
| Bildirim | FCM + uygulama içi bildirim listesi |

```
lib/
  app/                 tema (Güven Yeşili)
  core/                para (kuruş cinsinden tamsayı), tarih, Türkçe metin, ortak bileşenler
  features/ledger/     domain · data (LedgerRepository) · application (sağlayıcılar) · presentation
  features/profile/    profil
  screens/auth/        giriş, kayıt, e-posta doğrulama
  services/            kimlik, profil, push, derin link
functions/src/ledger/  komutlar, vade hesabı, hatırlatmalar, kişi/kod işlemleri
firestore.rules        güvenlik kuralları (testleri: firestore-tests/)
contracts/             Dart ve TypeScript'in ortak birim tanımları ve hash test vektörleri
```

## Geliştirme

```bash
flutter pub get
flutter run                      # hata ayıklama sürümü
flutter analyze && flutter test  # analiz ve birim/ekran testleri
```

Sunucu ve kural testleri Firebase emulator'ünde çalışır (Java 11+ gerekir):

```bash
cd functions && npm ci && npm run lint && npm run build
cd ../firestore-tests && npm ci
npm run emulator:test     # güvenlik kuralları
npm run functions:test    # defter komutları, hatırlatmalar, kişi ekleme
```

Her gönderimde GitHub Actions bu adımların hepsini çalıştırır.

## Yayın

- **Android yayın sürümü:** `android/key.properties` ve yükleme anahtarı gerekir. İkisi de depoya girmez; anahtar yoksa yayın derlemesi durur.
- **Sunucu kurulumu:** `firestore-tests/` içinde çalıştırılır.
  ```bash
  npx firebase deploy --only firestore,functions,hosting --project <proje>
  ```
  Hosting için önce `flutter build web` çalıştırılmalıdır.

Pacta yalnızca kayıt aracıdır: borç vermez, tahsilat yapmaz, para tutmaz.
