// lib/screens/auth/giris_ekrani.dart

import 'package:flutter/material.dart';
import 'package:pacta/screens/auth/kayit_ekrani.dart';
import 'package:pacta/services/auth_service.dart'; // Proje adını kontrol et
import 'package:pacta/screens/dashboard/dashboard_screen.dart'; // DashboardScreen'i ekledim

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // bool _rememberMe = false; // Artık kullanılmıyor

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Size size = MediaQuery.of(context).size;
    final double width = size.width;
    final double height = size.height;
    final cardColor = isDark ? const Color(0xFF23262F) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF111827);
    final textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final green = const Color(0xFF4ADE80);
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textMain,
        iconTheme: IconThemeData(color: textMain, size: width * 0.07),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: width * 0.07),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tekrar Hoş Geldin 👋',
                    style: TextStyle(
                      fontSize: width * 0.08,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
                  SizedBox(height: height * 0.01),
                  Text(
                    'Lütfen giriş yapmak için e-posta ve şifreni gir.',
                    style: TextStyle(fontSize: width * 0.045, color: textSec),
                  ),
                  SizedBox(height: height * 0.04),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'E-posta',
                      labelStyle: TextStyle(
                        color: textSec,
                        fontSize: width * 0.042,
                      ),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: textSec,
                        size: width * 0.06,
                      ),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: green, width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontSize: width * 0.045, color: textMain),
                  ),
                  SizedBox(height: height * 0.02),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      labelStyle: TextStyle(
                        color: textSec,
                        fontSize: width * 0.042,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: textSec,
                        size: width * 0.06,
                      ),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: green, width: 2),
                      ),
                      suffixIcon: Icon(
                        Icons.visibility_off,
                        color: textSec,
                        size: width * 0.06,
                      ),
                    ),
                    obscureText: true,
                    style: TextStyle(fontSize: width * 0.045, color: textMain),
                  ),
                  SizedBox(height: height * 0.012),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          // Şifremi unuttum fonksiyonu burada olacak
                        },
                        child: Text(
                          'Şifremi Unuttum?',
                          style: TextStyle(
                            fontSize: width * 0.042,
                            color: green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: height * 0.02),
                  SizedBox(
                    width: double.infinity,
                    height: height * 0.065,
                    child: ElevatedButton(
                      onPressed: () async {
                        final String? errorMessage = await _authService
                            .signInWithEmailAndPassword(
                              _emailController.text.trim(),
                              _passwordController.text.trim(),
                            );
                        if (errorMessage == null) {
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const DashboardScreen(),
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Giriş başarısız: $errorMessage'),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Giriş Yap',
                        style: TextStyle(
                          fontSize: width * 0.05,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: height * 0.015),
                  SizedBox(
                    width: double.infinity,
                    height: height * 0.065,
                    child: ElevatedButton.icon(
                      icon: Image.asset(
                        'assets/google_logo.png',
                        height: width * 0.06,
                        width: width * 0.06,
                      ),
                      label: Text(
                        'Google ile Giriş Yap',
                        style: TextStyle(fontSize: width * 0.045),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final String? errorMessage = await _authService
                            .googleSignIn();
                        if (errorMessage == null) {
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const DashboardScreen(),
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Google ile giriş başarısız: $errorMessage',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  SizedBox(height: height * 0.025),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Hesabın yok mu?',
                        style: TextStyle(
                          fontSize: width * 0.042,
                          color: textSec,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const KayitEkrani(),
                            ),
                          );
                        },
                        child: Text(
                          'Kayıt ol',
                          style: TextStyle(
                            fontSize: width * 0.045,
                            color: green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
