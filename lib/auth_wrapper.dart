// lib/auth_wrapper.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pacta/features/ledger/presentation/home_shell.dart';
import 'package:pacta/firebase_options.dart';
import 'package:pacta/screens/auth/giris_ekrani.dart';
import 'package:pacta/screens/auth/verify_email_screen.dart';
import 'package:pacta/services/auth_service.dart';

/// Hangi ekranın açılacağına tek başına karar verir:
/// - oturum yok → giriş,
/// - e-posta/şifre hesabı doğrulanmamış → doğrulama ekranı,
/// - oturum var → ana ekran (profil eksikse arka planda tamamlanır).
///
/// Giriş ve çıkış ekranları kendileri yönlendirme yapmaz; bu widget
/// kullanıcı değişikliğini (doğrulama dahil) dinleyip ekranı değiştirir.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late Future<void> _init = _ensureFirebase();
  String? _profileEnsuredFor;

  Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  void _retry() => setState(() => _init = _ensureFirebase());

  /// Profil, bildirim anahtarı yazımından önce ya da sonra fark etmeksizin
  /// eksik alanlarıyla tamamlanır. Kullanıcı başına bir kez çalışır.
  void _ensureProfile(User user) {
    if (_profileEnsuredFor == user.uid) return;
    _profileEnsuredFor = user.uid;
    AuthService().ensureProfile(user).catchError((Object e) {
      debugPrint('Profil tamamlanamadı: $e');
      _profileEnsuredFor = null; // sonraki açılışta tekrar denenir
    });
  }

  static bool _needsVerification(User user) =>
      !user.emailVerified &&
      user.providerData.any((p) => p.providerId == 'password');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, init) {
        if (init.hasError) return _ErrorScreen(onRetry: _retry);
        if (init.connectionState != ConnectionState.done) {
          return const _LoadingScreen();
        }
        return StreamBuilder<User?>(
          // userChanges: e-posta doğrulanınca (reload) da yayın yapar.
          stream: FirebaseAuth.instance.userChanges(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _ErrorScreen(onRetry: _retry);
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }
            final user = snapshot.data;
            if (user == null) {
              _profileEnsuredFor = null;
              return const GirisEkrani();
            }
            if (_needsVerification(user)) return const VerifyEmailScreen();
            _ensureProfile(user);
            return const HomeShell();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 56, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Bağlantı kurulamadı',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'İnternet bağlantınızı kontrol edip tekrar deneyin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
