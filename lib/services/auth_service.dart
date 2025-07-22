// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pacta/models/user_model.dart';
import 'package:pacta/services/firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Kullanıcı oturum durumunu dinleyen stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // --- GÜNCELLENMİŞ KAYIT METODU ---
  // Artık 4 parametre alıyor: email, password, adSoyad, ve telefon
  Future<String?> signUpWithEmailAndPassword(
    String email,
    String password,
    String adSoyad,
    String telefon,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      User? user = userCredential.user;

      if (user != null) {
        // Arama anahtarları oluşturma mantığı
        List<String> adSoyadParcalari = adSoyad.toLowerCase().split(' ');
        List<String> emailParcalari = email.toLowerCase().split('@');

        List<String> aramaListesi = [
          adSoyad.toLowerCase(),
          email.toLowerCase(),
          ...adSoyadParcalari,
          ...emailParcalari,
        ];
        if (telefon.isNotEmpty) {
          aramaListesi.add(telefon);
        }
        // Tekrarlananları silmek için Set kullanıp tekrar List'e çeviriyoruz
        aramaListesi = aramaListesi.toSet().toList();

        UserModel userModel = UserModel(
          uid: user.uid,
          email: user.email!,
          adSoyad: adSoyad,
          telefon: telefon,
          etiket: null, // Etiket şimdilik boş bırakılıyor
          aramaAnahtarlari: aramaListesi,
        );
        await _firestoreService.kullaniciOlustur(userModel);
      }
      return null; // Başarılı
    } on FirebaseAuthException catch (e) {
      return e.message; // Firebase'den gelen spesifik hata mesajını döndür
    } catch (e) {
      return e.toString(); // Diğer genel hatalar için
    }
  }

  // Giriş yapma metodu
  Future<String?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Başarılı, hata yok.
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Google ile giriş metodu
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
      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      User? user = userCredential.user;

      // Firestore'da kullanıcı var mı kontrol et, yoksa ekle
      if (user != null) {
        final userDoc = await _firestoreService.usersRef.doc(user.uid).get();
        if (!userDoc.exists) {
          UserModel userModel = UserModel(
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
          await _firestoreService.kullaniciOlustur(userModel);
        }
      }
      return null; // Başarılı
    } catch (e) {
      return e.toString();
    }
  }

  // Çıkış yapma metodu
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
