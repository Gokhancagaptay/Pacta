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

  // E-posta doğrulama/şifre sıfırlama bağlantısının dönüş adresi.
  static const String emailActionContinueUrl =
      'https://pacta-76686.web.app/auth/continue';

  // Android paket adı ve iOS bundle id.
  static const String androidPackageName = 'app.pacta.mobile';
  static const String iosBundleId = 'app.pacta.mobile';
}
