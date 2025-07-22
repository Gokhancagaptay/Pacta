// lib/auth_wrapper.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pacta/screens/auth/giris_ekrani.dart'; // Proje adını kontrol et
import 'package:pacta/screens/dashboard/dashboard_screen.dart'; // Proje adını kontrol et
import 'package:pacta/services/auth_service.dart'; // Proje adını kontrol et

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges, // Auth durumunu dinle
      builder: (context, snapshot) {
        // Bağlantı bekleniyor...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(), // Yükleniyor animasyonu
            ),
          );
        }

        // Kullanıcı giriş yapmış mı?
        if (snapshot.hasData) {
          // Evet, giriş yapmış -> Ana Sayfayı (Dashboard) göster
          return const DashboardScreen();
        } else {
          // Hayır, giriş yapmamış -> Giriş Ekranını göster
          return const GirisEkrani();
        }
      },
    );
  }
}
