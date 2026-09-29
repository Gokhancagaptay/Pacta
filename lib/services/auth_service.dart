// lib/services/auth_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pacta/core/report.dart';
import 'package:pacta/services/firestore_service.dart';
import 'package:pacta/services/notification_routes.dart';
import 'package:pacta/services/push_notification_service.dart';

/// Firebase Authentication işlemleri için servis sınıfı
///
/// Bu sınıf kullanıcı authentication işlemlerini yönetir:
/// - Email/şifre ile giriş ve kayıt
/// - Google ile giriş
/// - Şifre değiştirme
/// - Çıkış yapma
///
/// Tüm metotlar Türkçe error mesajları ve proper validation içerir.
class AuthService {
  /// Google hesap seçimi kapatıldı: hata olarak gösterilmez.
  static const googleCancelled = 'Google hesabı seçilmedi.';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthService() {
    // E-posta şablonlarının dilini Türkçe yap
    try {
      _auth.setLanguageCode('tr');
    } catch (_) {}
  }

  /// Şifre sıfırlama maili gönderir.
  ///
  /// Giriş yapılmadan kullanıcı listesi sorgulanamaz (firestore.rules); e-postanın
  /// kayıtlı olup olmadığını Firebase Auth kendisi değerlendirir.
  Future<String?> sendPasswordResetEmail(String email) async {
    if (email.isEmpty) return 'E-posta adresinizi girin.';
    try {
      final normalized = email.trim().toLowerCase();

      try {
        final settings = ActionCodeSettings(
          url: AppConstants.emailActionContinueUrl,
          handleCodeInApp: false,
          iOSBundleId: AppConstants.iosBundleId,
          androidPackageName: AppConstants.androidPackageName,
          androidInstallApp: true,
        );
        await _auth.sendPasswordResetEmail(
          email: normalized,
          actionCodeSettings: settings,
        );
      } on FirebaseAuthException catch (e) {
        // Domain/continueUrl yetkisi yoksa varsayılan mail gönderimine düş
        if (e.code == 'invalid-continue-uri' ||
            e.code == 'unauthorized-continue-uri') {
          await _auth.sendPasswordResetEmail(email: normalized);
        } else {
          rethrow;
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } catch (_) {
      return 'Şifre sıfırlama e-postası gönderilirken hata oluştu.';
    }
  }

  /// Kayıt: e-posta, şifre ve ad soyad. Telefon toplanmaz (kullanılan bir
  /// özellik yok; telefonla giriş gelince eklenecek).
  Future<String?> signUpWithEmailAndPassword(
    String email,
    String password,
    String adSoyad,
  ) async {
    if (email.isEmpty || password.isEmpty || adSoyad.isEmpty) {
      return 'Gerekli alanlar boş bırakılamaz.';
    }

    try {
      // Kullanımdaki e-posta için Firebase Auth `email-already-in-use` döner.
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      // Hesap açıldı ve oturum açık: sonraki adımlar en iyi çabayla yapılır.
      // Biri düşerse kullanıcıya "beklenmeyen hata" denmez (tekrar denemek
      // "e-posta kullanımda" der); profil AuthWrapper'da tamamlanır, koşullar
      // ekranı kabulü yeniden ister, doğrulama e-postası her durumda gider.
      try {
        await user?.updateDisplayName(adSoyad);
        if (user != null) {
          // Kayıt formu koşulların kabulü işaretlenmeden gönderilemez.
          await _firestoreService.ensureProfile(
            uid: user.uid,
            email: user.email ?? email,
            adSoyad: adSoyad,
            acceptedTerms: true,
          );
        }
      } catch (e, st) {
        reportError(e, st, reason: 'Kayıt sonrası profil yazılamadı');
      }
      try {
        await _sendVerificationWithSettings(user);
      } catch (e, st) {
        reportError(e, st, reason: 'Doğrulama e-postası gönderilemedi');
      }
      return null; // doğrulama bekleniyor
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      debugPrint('Unexpected error during sign up: $e');
      return 'Beklenmeyen bir hata oluştu.';
    }
  }

  /// E-posta ve şifreyle giriş; hata varsa Türkçe mesaj döner.
  Future<String?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    if (email.isEmpty || password.isEmpty) {
      return 'E-posta ve şifre boş bırakılamaz.';
    }

    try {
      // Doğrulanmamış hesap giriş yapar ama AuthWrapper onu doğrulama
      // ekranında tutar (oradan bağlantı yeniden gönderilebilir). Profil de
      // AuthWrapper'da tamamlanır.
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      debugPrint('Unexpected error during sign in: $e');
      return 'Beklenmeyen bir hata oluştu.';
    }
  }

  /// Doğrulama e-postasını tekrar gönderir; hata varsa Türkçe mesaj döner.
  Future<String?> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return null;
    try {
      await _sendVerificationWithSettings(user);
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    }
  }

  /// E-posta doğrulandı mı? Doğrulandıysa kimlik belirteci yenilenir; sunucu
  /// "doğrulanmış" bilgisini ancak yeni belirteçte görür.
  Future<bool> refreshEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final fresh = _auth.currentUser;
    if (fresh == null || !fresh.emailVerified) return false;
    await fresh.getIdToken(true);
    return true;
  }

  /// Giriş yapmış kullanıcının profilini oluşturur ya da tamamlar.
  Future<void> ensureProfile(User user) => _firestoreService.ensureProfile(
    uid: user.uid,
    email: user.email ?? '',
    adSoyad: user.displayName,
    telefon: user.phoneNumber,
  );

  // Email doğrulama linkine continueUrl ekler (Dynamic Links olmadan)
  Future<void> _sendVerificationWithSettings(User? user) async {
    if (user == null) return;
    try {
      final settings = ActionCodeSettings(
        url: AppConstants.emailActionContinueUrl,
        handleCodeInApp: false,
        iOSBundleId: AppConstants.iosBundleId,
        androidPackageName: AppConstants.androidPackageName,
        androidInstallApp: true,
      );
      await user.sendEmailVerification(settings);
    } on FirebaseAuthException catch (e) {
      // Alan adı veya continue URL yetkili değilse, varsayılan doğrulama e-postasını gönder
      if (e.code == 'invalid-continue-uri' ||
          e.code == 'unauthorized-continue-uri') {
        await user.sendEmailVerification();
        return;
      }
      rethrow;
    } catch (_) {
      // Her ihtimale karşı sessiz geri dönüş
      await user.sendEmailVerification();
    }
  }

  /// Firebase Auth hatalarını kullanıcıya gösterilecek Türkçe mesaja çevirir.
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      // E-posta numaralandırma koruması açıkken Firebase "kullanıcı yok",
      // "şifre yanlış" ve "hesabın şifresi yok (Google ile açılmış)"
      // durumlarını tek kodla bildirir.
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
      case 'user-not-found':
      case 'wrong-password':
        return 'E-posta ya da şifre hatalı. Hesabı Google ile açtıysanız '
            '"Google ile devam et"i kullanın; şifrenizi unuttuysanız '
            '"Şifremi unuttum"a dokunun.';
      case 'account-exists-with-different-credential':
        return 'Bu e-posta adresi başka bir giriş yöntemiyle kayıtlı. E-posta '
            've şifrenizle giriş yapın.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'weak-password':
        return 'Bu şifre çok zayıf. Daha uzun ya da tahmin edilmesi zor bir '
            'şifre seçin.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Birkaç dakika sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edin.';
      case 'invalid-continue-uri':
      case 'unauthorized-continue-uri':
        // Yapılandırma hatası: kullanıcıya konsol talimatı gösterilmez.
        debugPrint('E-posta bağlantısı alanı yetkili değil: ${e.code}');
        return 'E-posta şu an gönderilemiyor. Biraz sonra tekrar deneyin.';
      default:
        // Firebase'in İngilizce mesajı kullanıcıya gösterilmez.
        debugPrint('Kimlik hatası: ${e.code} ${e.message}');
        return 'İşlem tamamlanamadı. Tekrar deneyin.';
    }
  }

  /// Google ile giriş; hata varsa Türkçe mesaj döner.
  Future<String?> googleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return googleCancelled;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Profil AuthWrapper'da oluşturulur/tamamlanır.
      await _auth.signInWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      await _forgetGoogleAccount();
      return _handleAuthError(e);
    } catch (e) {
      await _forgetGoogleAccount();
      debugPrint('Unexpected error during Google sign in: $e');
      return 'Google ile giriş yapılırken hata oluştu.';
    }
  }

  /// Çıkış: önce bu cihazın bildirim anahtarı hesaptan silinir ve iptal
  /// edilir (yoksa çıkan kişinin bildirimleri bu cihaza gelmeye devam eder),
  /// Google oturumu da kapatılır ki başka hesap seçilebilsin. İnternet yoksa
  /// çıkış beklemez. Sonra cihazdaki Firestore önbelleği (defterler,
  /// kayıtlar) silinir; telefonda önceki kişinin verisi kalmaz.
  Future<void> signOut() async {
    const wait = Duration(seconds: 3);
    await PushNotificationService.instance.forgetDevice(wait: wait);
    try {
      await _googleSignIn.signOut().timeout(wait);
    } catch (_) {}
    await _auth.signOut();
    NotificationRoutes.clear();
    await clearLocalData();
  }

  /// Firestore'un cihazdaki önbelleğini siler. Eklenti sonlandırılan örneği
  /// bırakır; sonraki kullanımda yenisi açılır.
  static Future<void> clearLocalData() async {
    try {
      final db = FirebaseFirestore.instance;
      await db.terminate();
      await db.clearPersistence();
    } catch (e, st) {
      reportError(e, st, reason: 'Yerel veri temizlenemedi');
    }
  }

  /// Mevcut şifreyle yeniden doğrulayıp şifreyi değiştirir.
  Future<String?> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      return 'Mevcut şifre ve yeni şifre boş bırakılamaz.';
    }

    if (newPassword.length < 8) {
      return 'Yeni şifre en az 8 karakter olmalı.';
    }

    try {
      final user = _auth.currentUser;
      if (user?.email == null) {
        return 'Kullanıcı bilgisi bulunamadı.';
      }

      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      // Burada tek olası "hatalı giriş" mevcut şifredir.
      if (const {
        'invalid-credential',
        'INVALID_LOGIN_CREDENTIALS',
        'wrong-password',
      }.contains(e.code)) {
        return 'Mevcut şifre yanlış.';
      }
      return _handleAuthError(e);
    } catch (e) {
      debugPrint('Unexpected error during password change: $e');
      return 'Şifre değiştirilirken hata oluştu.';
    }
  }

  /// Hesap şifreyle mi açıldı (değilse Google ile).
  bool get isPasswordUser =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  /// Geri alınamaz işlemden (hesap silme) önce kimliği yeniden doğrular.
  /// Başarısız girişten sonra: Google son hesabı sessizce yeniden seçmesin,
  /// kullanıcı başka hesap seçebilsin.
  Future<void> _forgetGoogleAccount() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  /// Şifreli hesapta [password] gerekir; Google hesabında Google seçici açılır.
  /// Başarılıysa null, değilse Türkçe hata mesajı döner.
  Future<String?> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) return 'Oturum bulunamadı. Yeniden giriş yapın.';
    try {
      final AuthCredential credential;
      if (isPasswordUser) {
        if (password == null || password.isEmpty) return 'Şifrenizi girin.';
        credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
      } else {
        // Önce çıkış: yoksa son hesap sessizce yeniden kullanılır, seçici
        // açılmaz (kilidi açık telefon koruması tek dokunuşa iner).
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
        final account = await _googleSignIn.signIn();
        if (account == null) return 'Google hesabı seçilmedi.';
        final auth = await account.authentication;
        credential = GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        );
      }
      await user.reauthenticateWithCredential(credential);
      // Sunucu, belirteçteki giriş zamanına bakar.
      await user.getIdToken(true);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-mismatch':
          return 'Farklı bir hesap seçtiniz. Bu hesabın Google hesabıyla '
              'doğrulayın.';
        case 'invalid-credential':
        case 'INVALID_LOGIN_CREDENTIALS':
        case 'wrong-password':
          return 'Şifre yanlış.';
        case 'user-not-found':
        case 'user-disabled':
        case 'user-token-expired':
          return 'Bu hesap artık yok. Çıkış yapıp yeniden deneyin.';
      }
      return _handleAuthError(e);
    } catch (e) {
      debugPrint('Yeniden doğrulama hatası: $e');
      return 'Doğrulama yapılamadı. Tekrar deneyin.';
    }
  }

  /// Hesap sunucuda silinmiş mi (cihazda oturum kalmış olsa bile).
  Future<bool> isCurrentUserGone() async {
    final user = _auth.currentUser;
    if (user == null) return true;
    try {
      await user.reload();
      return false;
    } on FirebaseAuthException catch (e) {
      return const {
        'user-not-found',
        'user-disabled',
        'user-token-expired',
      }.contains(e.code);
    } catch (_) {
      return false; // bağlantı yok vb.: karar verilemez
    }
  }
}
