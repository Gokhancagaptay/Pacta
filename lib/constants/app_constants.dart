// lib/constants/app_constants.dart

/// Uygulama genelinde kullanılan sabit değerler.
class AppConstants {
  AppConstants._();

  static const String appName = 'Pacta';

  // Koleksiyon adları (profil; defter koleksiyonları LedgerRepository'de).
  static const String usersCollection = 'users';
  static const String publicProfilesCollection = 'publicProfiles';

  // Cloud Functions bölgesi (functions/src/common/firebase.ts ile aynı olmalı).
  static const String functionsRegion = 'europe-west1';

  // Web sitesi (davet linki, yasal sayfalar, e-posta dönüş sayfası).
  static const String webBaseUrl = 'https://pacta-76686.web.app';

  // E-posta doğrulama/şifre sıfırlama bağlantısının dönüş adresi.
  static const String emailActionContinueUrl = '$webBaseUrl/auth/continue';

  // Kullanım Koşulları ve Gizlilik metninin sürümü. Metin, kullanıcıdan
  // yeniden kabul istenecek şekilde değişirse güncellenir; herkes bir
  // sonraki açılışta yeni metni onaylar (users.termsVersion).
  static const String termsVersion = '2026-09-27';

  // Android paket adı ve iOS bundle id.
  static const String androidPackageName = 'app.pacta.mobile';
  static const String iosBundleId = 'app.pacta.mobile';
}
