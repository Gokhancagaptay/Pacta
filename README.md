# Pacta 🤝 | Akıllı Borç ve Finans Takip Asistanı

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)
![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)

**Pacta**, kişisel finansal ilişkilerinizi, borç ve alacak durumlarınızı dijital ortamda güvenle yönetmenizi sağlayan modern bir mobil uygulamadır. Gelişmiş analiz araçları, PDF raporlama ve anlık bildirimlerle finansal hafızanızı güçlendirir.

---

## 📱 Ekran Görüntüleri

| Giriş Ekranı | Ana Panel | İşlem Detayı | Analizler |
|:---:|:---:|:---:|:---:|
| <img src="assets/screenshots/login.png" width="200"/> | <img src="assets/screenshots/dashboard.png" width="200"/> | <img src="assets/screenshots/detail.png" width="200"/> | <img src="assets/screenshots/analysis.png" width="200"/> |

---

## 🌟 Temel Özellikler

### 🔐 Güvenlik ve Kimlik
* **Firebase Auth:** E-posta ve şifre ile güvenli giriş/kayıt altyapısı.
* **Profil Yönetimi:** Kullanıcı profili düzenleme ve güvenli şifre değiştirme işlemleri.

### 💰 Finansal Yönetim
* **Borç/Alacak Takibi:** İşlemleri kişi, tutar, tarih ve açıklama detaylarıyla kaydetme.
* **Detaylı İşlem Geçmişi:** Tüm finansal hareketlerinizi filtreleyin ve görüntüleyin.
* **Kişi Bazlı Cüzdan:** Rehberinizdeki veya kaydettiğiniz kişilerle olan bakiyenizi anlık görün.

### 📊 Analiz ve Raporlama
* **Akıllı Grafikler:** Gelir/Gider dengenizi ve genel durumunuzu görsel grafiklerle analiz edin.
* **Kişi Analizi:** Özel bir kişiyle olan finansal ilişkinizin derinlemesine analizi (`ContactAnalysisScreen`).
* **Belge Oluşturma:** Verilerinizi PDF veya Excel formatında dışarı aktarın (`GenerateDocumentScreen`).

### 🔔 Bildirim Sistemi
* **Anlık Uyarılar:** Firebase Cloud Messaging (FCM) ile ödeme hatırlatmaları ve işlem bildirimleri.
* **Özelleştirme:** Bildirim ayarlarını kişisel tercihlerinize göre yapılandırın.

---

## 🛠️ Teknik Altyapı

Bu proje **Clean Architecture** prensiplerine sadık kalınarak, ölçeklenebilir bir yapıda geliştirilmiştir.

* **Frontend:** Flutter (Dart)
* **Backend:** Firebase (Firestore, Cloud Functions, Storage)
* **State Management:** Provider
* **Servisler:** * `AuthService`: Kimlik doğrulama işlemleri.
  * `FirestoreService`: Veritabanı CRUD operasyonları.
  * `PushNotificationService`: Bildirim yönetimi.
* **UI/UX:** Özel tema yapılandırması (`app_theme.dart`) ve yeniden kullanılabilir widget kütüphanesi.

---

## 📂 Proje Mimarisi

```text
lib/
├── constants/       # Sabitler (Renkler, Stringler)
├── models/          # Veri Modelleri (Debt, User, Contact)
├── providers/       # State Management (Theme Provider)
├── screens/         # Uygulama Sayfaları
│   ├── analysis/    # Grafik ve Raporlama
│   ├── auth/        # Giriş/Kayıt
│   ├── contacts/    # Kişi Listesi
│   ├── dashboard/   # Ana Gösterge Paneli
│   ├── debt/        # İşlem Ekleme/Detay
│   └── settings/    # Ayarlar
├── services/        # Firebase Servisleri
├── theme/           # Tema Ayarları
├── utils/           # Yardımcı Fonksiyonlar (Format, Validasyon)
└── widgets/         # Ortak Kullanılan Bileşenler
