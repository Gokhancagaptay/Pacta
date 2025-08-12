// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pacta/models/user_model.dart';
import 'package:pacta/services/firestore_service.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthService() {
    // E-posta şablonlarının dilini Türkçe yap
    try {
      _auth.setLanguageCode('tr');
    } catch (_) {}
  }

  /// E-posta doğrulaması tamamlanmış kullanıcılar için şifre sıfırlama maili gönderir
  /// - Firestore'da kullanıcı dokümanı yoksa (muhtemelen doğrulanmamış) göndermez
  Future<String?> sendPasswordResetEmailIfVerified(String email) async {
    if (email.isEmpty) return 'Lütfen e-posta adresinizi girin.';
    try {
      // Firestore'da kullanıcı dokümanı var mı? (Biz doğrulamadan sonra oluşturuyoruz)
      final normalized = email.trim().toLowerCase();
      final userDoc = await _firestoreService.getUserByEmailInsensitive(
        normalized,
      );
      if (userDoc == null) {
        return 'Bu e-posta için doğrulama tamamlanmamış. Lütfen önce e-postanızı doğrulayın.';
      }

      try {
        final settings = ActionCodeSettings(
          url: AppConstants.emailActionContinueUrl,
          handleCodeInApp: false,
          iOSBundleId: AppConstants.iosBundleId,
          androidPackageName: AppConstants.androidPackageName,
          androidInstallApp: true,
          androidMinimumVersion: '21',
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

  // Kullanıcı oturum durumunu dinleyen stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Kayıt metodu: Email, şifre, ad soyad ve telefon ile yeni kullanıcı oluşturur
  Future<String?> signUpWithEmailAndPassword(
    String email,
    String password,
    String adSoyad,
    String telefon,
  ) async {
    // Input validation
    if (email.isEmpty || password.isEmpty || adSoyad.isEmpty) {
      return 'Gerekli alanlar boş bırakılamaz.';
    }

    try {
      // Check if email is already in use
      final existingUserByEmail = await _firestoreService.getUserByEmail(email);
      if (existingUserByEmail != null) {
        return 'Bu e-posta adresi zaten kullanımda.';
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Profil ismi güncelle ve doğrulama maili gönder (özelleştirilmiş linklerle)
      await userCredential.user?.updateDisplayName(adSoyad);
      await _sendVerificationWithSettings(userCredential.user);

      // Not: Firestore kullanıcı dokümanı e-posta doğrulandıktan sonra oluşturulacak
      return null; // Success (doğrulama bekleniyor)
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      print('Unexpected error during sign up: $e');
      return 'Beklenmeyen bir hata oluştu.';
    }
  }

  /// Giriş yapma metodu
  Future<String?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    // Input validation
    if (email.isEmpty || password.isEmpty) {
      return 'E-posta ve şifre boş bırakılamaz.';
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!(credential.user?.emailVerified ?? false)) {
        // Doğrulanmamış hesapla girişe izin verme
        await _sendVerificationWithSettings(credential.user);
        await _auth.signOut();
        return 'E-posta adresinizi doğrulamalısınız. Doğrulama maili tekrar gönderildi.';
      }
      // Doğrulanmış hesabın Firestore dokümanı yoksa oluştur
      final user = _auth.currentUser;
      if (user != null) {
        await _createUserIfNotExists(user);
      }
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      print('Unexpected error during sign in: $e');
      return 'Beklenmeyen bir hata oluştu.';
    }
  }

  /// Doğrulama e-postasını tekrar gönderir
  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !(user.emailVerified)) {
      await _sendVerificationWithSettings(user);
    }
  }

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
        androidMinimumVersion: '21',
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

  /// E-posta doğrulandıysa kullanıcı dokümanını oluşturur ve true döner
  Future<bool> finalizeUserAfterEmailVerification({
    required String adSoyad,
    required String telefon,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    if (user.emailVerified) {
      // Kullanıcı dokümanı yoksa oluştur
      final userDoc = await _firestoreService.usersRef.doc(user.uid).get();
      if (!userDoc.exists) {
        final userModel = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          adSoyad: adSoyad,
          telefon: telefon,
          etiket: null,
          aramaAnahtarlari: [
            adSoyad.toLowerCase(),
            (user.email ?? '').toLowerCase(),
          ],
        );
        await _firestoreService.createUser(userModel);
      }
      return true;
    }
    return false;
  }

  /// Firebase Auth hatalarını Türkçe mesajlara çeviren yardımcı metod
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Bu e-posta adresi ile kayıtlı kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Hatalı şifre girdiniz.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'weak-password':
        return 'Şifre çok zayıf. Lütfen daha güçlü bir şifre seçin.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'too-many-requests':
        return 'Çok fazla deneme yaptınız. Lütfen daha sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edin.';
      case 'invalid-continue-uri':
      case 'unauthorized-continue-uri':
        return 'Doğrulama bağlantısı alanı bu proje için yetkili değil. Firebase Console > Authentication > Settings > Authorized domains bölümünden izin verin.';
      default:
        return e.message ?? 'Bilinmeyen bir hata oluştu.';
    }
  }

  /// Google ile giriş metodu
  Future<String?> googleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return 'Google hesabı seçilmedi.';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      // Create user document if doesn't exist
      if (user != null) {
        await _createUserIfNotExists(user);
      }

      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      print('Unexpected error during Google sign in: $e');
      return 'Google ile giriş yapılırken hata oluştu.';
    }
  }

  /// Kullanıcı yoksa Firestore'da oluşturan yardımcı metod
  Future<void> _createUserIfNotExists(User user) async {
    final userDoc = await _firestoreService.usersRef.doc(user.uid).get();
    if (!userDoc.exists) {
      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        adSoyad: user.displayName ?? '',
        telefon: user.phoneNumber ?? '',
        etiket: null,
        aramaAnahtarlari: [
          user.displayName?.toLowerCase() ?? '',
          user.email?.toLowerCase() ?? '',
        ],
      );
      await _firestoreService.createUser(userModel);
    }
  }

  // Çıkış yapma metodu
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // E-posta güncelleme metodu
  Future<void> updateEmail(String newEmail) async {
    await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail);
  }

  /// Şifre değiştirme metodu
  Future<String?> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    // Input validation
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      return 'Mevcut şifre ve yeni şifre boş bırakılamaz.';
    }

    if (newPassword.length < 6) {
      return 'Yeni şifre en az 6 karakter olmalıdır.';
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
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      print('Unexpected error during password change: $e');
      return 'Şifre değiştirilirken hata oluştu.';
    }
  }
}
