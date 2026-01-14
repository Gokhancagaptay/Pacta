Pacta 🤝
Pacta, kullanıcıların finansal işlemlerini, borç ve alacak durumlarını, kişilerini ve ödeme geçmişlerini güvenli ve modern bir arayüzle yönetmelerini sağlayan, Flutter ile geliştirilmiş çapraz platform (Android & iOS) bir mobil uygulamadır.

🌟 Özellikler
Uygulama, kullanıcı deneyimini ön planda tutan aşağıdaki temel özelliklere sahiptir:

🔐 Güvenli Kimlik Doğrulama:

E-posta ve şifre ile giriş/kayıt işlemleri.

Firebase Authentication altyapısı.

Profil düzenleme ve şifre değiştirme seçenekleri.

💰 Borç ve Alacak Yönetimi:

Yeni borç veya alacak kaydı oluşturma.

İşlem detaylarını görüntüleme.

Tutar ve tarih bazlı takip.

👥 Kişi Yönetimi (Contacts):

Kişileri kaydetme ve yönetme.

Kişiye özel işlem geçmişi görüntüleme.

Kişi bazlı finansal analizler (ContactAnalysisScreen).

📊 Analiz ve Raporlama:

Kullanıcı genel durum analizi.

Belge ve rapor oluşturma (GenerateDocumentScreen).

Grafiksel verilerle finansal durumu izleme.

🔔 Bildirim Sistemi:

Ödeme hatırlatıcıları ve işlem bildirimleri.

Firebase Cloud Messaging (FCM) entegrasyonu.

Özelleştirilebilir bildirim ayarları.

☁️ Bulut Tabanlı Veri:

Firebase Firestore ile gerçek zamanlı veri senkronizasyonu.

Firebase Cloud Functions ile sunucu tarafı mantık işlemleri.

📂 Proje Yapısı
Proje, temiz mimari prensiplerine uygun olarak modüler bir yapıda geliştirilmiştir:

Plaintext

lib/
├── constants/       # Uygulama genelinde kullanılan sabitler ve metinler
├── models/          # Veri modelleri (Debt, User, Notification vb.)
├── providers/       # State management (Theme provider vb.)
├── screens/         # Uygulama ekranları (UI)
│   ├── analysis/    # Analiz ve rapor ekranları
│   ├── auth/        # Giriş ve kayıt ekranları
│   ├── contacts/    # Kişi listesi ve detayları
│   ├── dashboard/   # Ana kontrol paneli
│   ├── debt/        # İşlem ekleme ve listeleme
│   ├── notifications/
│   └── settings/    # Ayarlar ve profil yönetimi
├── services/        # Firebase ve diğer servisler (Auth, Firestore, Push Notification)
├── theme/           # Tema ve renk yapılandırmaları
├── utils/           # Yardımcı fonksiyonlar (Validasyon, Formatlama, Renkler)
└── widgets/         # Yeniden kullanılabilir bileşenler
functions/           # Firebase Cloud Functions (TypeScript)
🚀 Kurulum ve Çalıştırma
Projeyi yerel makinenizde çalıştırmak için aşağıdaki adımları izleyin:

Gereksinimler
Flutter SDK (Son sürüm)

Dart SDK

Android Studio veya VS Code

Adımlar
Projeyi Klonlayın:

Bash

git clone https://github.com/kullaniciadi/pacta.git
cd pacta
Bağımlılıkları Yükleyin:

Bash

flutter pub get
Firebase Yapılandırması:

Bu proje Firebase kullanmaktadır.

android/app/google-services.json ve ios/Runner/GoogleService-Info.plist dosyalarınızın doğru yerleştirildiğinden emin olun.

Firebase CLI kullanarak yapılandırmayı güncelleyebilirsiniz:

Bash

flutterfire configure
Uygulamayı Başlatın:

Bash

flutter run
🛠️ Kullanılan Teknolojiler
Frontend: Flutter & Dart

Backend: Firebase (Firestore, Authentication, Cloud Functions, Storage)

State Management: Provider (veya kullanılan diğer yapı)

Bildirimler: Firebase Cloud Messaging

🤝 Katkıda Bulunma
Bu repoyu "Fork"layın.

Yeni bir özellik dalı (branch) oluşturun (git checkout -b ozellik/YeniOzellik).

Değişikliklerinizi "Commit"leyin (git commit -m 'Yeni özellik eklendi').

Dalınızı "Push"layın (git push origin ozellik/YeniOzellik).

Bir "Pull Request" oluşturun.
