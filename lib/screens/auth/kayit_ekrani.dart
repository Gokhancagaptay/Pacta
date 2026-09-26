// lib/screens/auth/kayit_ekrani.dart

import 'package:flutter/material.dart';
import 'package:pacta/services/auth_service.dart';

class KayitEkrani extends StatefulWidget {
  const KayitEkrani({super.key});

  @override
  State<KayitEkrani> createState() => _KayitEkraniState();
}

class _KayitEkraniState extends State<KayitEkrani> {
  final AuthService _authService = AuthService();
  final TextEditingController _adSoyadController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _agreed = false;
  bool _isPasswordObscured = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
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
                    'Hesap Oluştur 👤',
                    style: TextStyle(
                      fontSize: size.width * 0.08,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
                  SizedBox(height: size.height * 0.01),
                  Text(
                    'Kayıt olmak için bilgilerini doldur.',
                    style: TextStyle(
                      fontSize: size.width * 0.045,
                      color: textSec,
                    ),
                  ),
                  SizedBox(height: size.height * 0.04),
                  _buildTextField(
                    controller: _adSoyadController,
                    labelText: 'Ad Soyad',
                    icon: Icons.person_outline,
                  ),
                  SizedBox(height: size.height * 0.02),
                  _buildTextField(
                    controller: _emailController,
                    labelText: 'E-posta',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: size.height * 0.02),
                  _buildTextField(
                    controller: _telefonController,
                    labelText: 'Telefon (isteğe bağlı)',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: size.height * 0.02),
                  _buildTextField(
                    controller: _passwordController,
                    labelText: 'Şifre',
                    icon: Icons.lock_outline,
                    obscureText: _isPasswordObscured,
                    suffixIcon: _isPasswordObscured
                        ? Icons.visibility_off
                        : Icons.visibility,
                    onSuffixTap: () {
                      setState(() {
                        _isPasswordObscured = !_isPasswordObscured;
                      });
                    },
                  ),
                  SizedBox(height: size.height * 0.02),
                  _buildAgreementCheckbox(),
                  SizedBox(height: size.height * 0.025),
                  SizedBox(
                    width: double.infinity,
                    height: size.height * 0.065,
                    child: ElevatedButton(
                      onPressed: _agreed ? _signUp : null,
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
                        'Kayıt Ol',
                        style: TextStyle(
                          fontSize: size.width * 0.05,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.025),
                  _buildLoginRedirect(),
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
    VoidCallback? onSuffixTap,
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
            ? IconButton(
                onPressed: onSuffixTap,
                icon: Icon(suffixIcon, color: textSec, size: size.width * 0.06),
              )
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

  Widget _buildAgreementCheckbox() {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final green = const Color(0xFF4ADE80);

    return Row(
      children: [
        Checkbox(
          value: _agreed,
          onChanged: (val) {
            setState(() {
              _agreed = val ?? false;
            });
          },
          activeColor: green,
          checkColor: Colors.white,
          side: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(size.width * 0.015),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        SizedBox(width: size.width * 0.015),
        Expanded(
          child: Text(
            'Kullanım Şartları ve Gizlilik Politikasını kabul ediyorum.',
            style: TextStyle(fontSize: size.width * 0.038, color: textSec),
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginRedirect() {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final green = const Color(0xFF4ADE80);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Zaten bir hesabın var mı?',
          style: TextStyle(fontSize: size.width * 0.042, color: textSec),
        ),
        TextButton(
          // Kayıt ekranı giriş ekranının üstünde açılır; geri dönmek yeterli.
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(
            'Giriş Yap',
            style: TextStyle(
              fontSize: size.width * 0.045,
              color: green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _signUp() async {
    final String? errorMessage = await _authService.signUpWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _adSoyadController.text.trim(),
      _telefonController.text.trim(),
    );
    if (!mounted) return;
    if (errorMessage == null) {
      // Oturum açıldı ama e-posta doğrulanmadı: en alttaki sayfaya dönülür,
      // AuthWrapper doğrulama ekranını gösterir (bağlantı orada yeniden
      // gönderilebilir, doğrulanınca otomatik devam edilir).
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kayıt başarısız: $errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
