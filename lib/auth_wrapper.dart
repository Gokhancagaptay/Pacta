// lib/auth_wrapper.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pacta/screens/auth/giris_ekrani.dart'; // Proje adını kontrol et
import 'package:pacta/screens/dashboard/dashboard_screen.dart'; // Proje adını kontrol et
import 'package:pacta/services/auth_service.dart'; // Proje adını kontrol et

/// Authentication durumunu kontrol eden wrapper widget
///
/// Bu widget kullanıcının giriş durumunu kontrol eder ve
/// uygun ekranı gösterir:
/// - Giriş yapmışsa: Dashboard
/// - Giriş yapmamışsa: Login ekranı
/// - Bağlantı hatası: Error ekranı
/// - Yüklenirken: Loading ekranı
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Handle connection states
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
            return _buildLoadingScreen();
          case ConnectionState.active:
            return _buildAuthenticatedContent(snapshot);
          case ConnectionState.done:
          case ConnectionState.none:
            // Connection closed or no connection - redirect to login
            return const GirisEkrani();
        }
      },
    );
  }

  /// Loading screen widget
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.deepPurple.shade400,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Giriş kontrol ediliyor...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build content based on authentication state
  Widget _buildAuthenticatedContent(AsyncSnapshot<User?> snapshot) {
    if (snapshot.hasError) {
      return _buildErrorScreen(snapshot.error.toString());
    }

    if (snapshot.hasData && snapshot.data != null) {
      // User is authenticated
      return const DashboardScreen();
    } else {
      // User is not authenticated
      return const GirisEkrani();
    }
  }

  /// Error screen widget
  Widget _buildErrorScreen(String error) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                'Bağlantı Hatası',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Restart the app or retry connection
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
