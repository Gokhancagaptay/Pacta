// lib/screens/auth/giris_ekrani.dart

import 'package:flutter/material.dart';
import 'package:pacta/screens/auth/kayit_ekrani.dart';
import 'package:pacta/services/auth_service.dart';
import 'package:pacta/screens/dashboard/dashboard_screen.dart';

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
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
        iconTheme: IconThemeData(color: textMain, size: size.width * 0.07),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.07),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tekrar Hoş Geldin 👋',
                    style: TextStyle(
                      fontSize: size.width * 0.08,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
                  SizedBox(height: size.height * 0.01),
                  Text(
                    'Lütfen giriş yapmak için e-posta ve şifreni gir.',
                    style: TextStyle(
                      fontSize: size.width * 0.045,
                      color: textSec,
                    ),
                  ),
                  SizedBox(height: size.height * 0.04),
                  _buildTextField(
                    controller: _emailController,
                    labelText: 'E-posta',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: size.height * 0.02),
                  _buildTextField(
                    controller: _passwordController,
                    labelText: 'Şifre',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    suffixIcon: Icons.visibility_off,
                  ),
                  SizedBox(height: size.height * 0.012),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          // Şifremi unuttum fonksiyonu
                        },
                        child: Text(
                          'Şifremi Unuttum?',
                          style: TextStyle(
                            fontSize: size.width * 0.042,
                            color: green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: size.height * 0.02),
                  SizedBox(
                    width: double.infinity,
                    height: size.height * 0.065,
                    child: ElevatedButton(
                      onPressed: _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            size.width * 0.04,
                          ),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Giriş Yap',
                        style: TextStyle(
                          fontSize: size.width * 0.05,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.015),
                  SizedBox(
                    width: double.infinity,
                    height: size.height * 0.065,
                    child: ElevatedButton.icon(
                      icon: Image.asset(
                        'assets/google_logo.png',
                        height: size.width * 0.06,
                        width: size.width * 0.06,
                      ),
                      label: Text(
                        'Google ile Giriş Yap',
                        style: TextStyle(fontSize: size.width * 0.045),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            size.width * 0.04,
                          ),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _googleSignIn,
                    ),
                  ),
                  SizedBox(height: size.height * 0.025),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Hesabın yok mu?',
                        style: TextStyle(
                          fontSize: size.width * 0.042,
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
                            fontSize: size.width * 0.045,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool obscureText = false,
    IconData? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final cardColor = isDark ? const Color(0xFF23262F) : Colors.white;
    final green = const Color(0xFF4ADE80);
    final textMain = isDark ? Colors.white : const Color(0xFF111827);

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: textSec, fontSize: size.width * 0.042),
        prefixIcon: Icon(icon, color: textSec, size: size.width * 0.06),
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, color: textSec, size: size.width * 0.06)
            : null,
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(size.width * 0.04),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(size.width * 0.04),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(size.width * 0.04),
          borderSide: BorderSide(color: green, width: 2),
        ),
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: size.width * 0.045, color: textMain),
    );
  }

  void _signIn() async {
    final String? errorMessage = await _authService.signInWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (errorMessage == null && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Giriş başarısız: $errorMessage')));
    }
  }

  void _googleSignIn() async {
    final String? errorMessage = await _authService.googleSignIn();
    if (errorMessage == null && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google ile giriş başarısız: $errorMessage')),
      );
    }
  }
}
