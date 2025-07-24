// lib/screens/auth/kayit_ekrani.dart

import 'package:flutter/material.dart';
import 'package:pacta/screens/auth/giris_ekrani.dart'; // Giriş ekranına yönlendirme için import
import 'package:pacta/services/auth_service.dart';

class KayitEkrani extends StatefulWidget {
  const KayitEkrani({super.key});

  @override
  State<KayitEkrani> createState() => _KayitEkraniState();
}

class _KayitEkraniState extends State<KayitEkrani> {
  final AuthService _authService = AuthService();
  // --- EKSİK OLAN CONTROLLER'I EKLİYORUZ ---
  final TextEditingController _adSoyadController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonController =
      TextEditingController(); // Bu eksikti
  final TextEditingController _passwordController = TextEditingController();
  bool _agreed = false;

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
                    'Hesap Oluştur 👤',
                    style: TextStyle(
                      fontSize: width * 0.08,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
                  SizedBox(height: height * 0.01),
                  Text(
                    'Kayıt olmak için bilgilerini doldur.',
                    style: TextStyle(fontSize: width * 0.045, color: textSec),
                  ),
                  SizedBox(height: height * 0.04),
                  TextField(
                    controller: _adSoyadController,
                    decoration: InputDecoration(
                      labelText: 'Ad Soyad',
                      labelStyle: TextStyle(
                        color: textSec,
                        fontSize: width * 0.042,
                      ),
                      prefixIcon: Icon(
                        Icons.person_outline,
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
                    style: TextStyle(fontSize: width * 0.045, color: textMain),
                  ),
                  SizedBox(height: height * 0.02),
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
                    controller: _telefonController,
                    decoration: InputDecoration(
                      labelText: 'Telefon (isteğe bağlı)',
                      labelStyle: TextStyle(
                        color: textSec,
                        fontSize: width * 0.042,
                      ),
                      prefixIcon: Icon(
                        Icons.phone_outlined,
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
                    keyboardType: TextInputType.phone,
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
                  SizedBox(height: height * 0.02),
                  Row(
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
                          borderRadius: BorderRadius.circular(6),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      SizedBox(width: width * 0.015),
                      Expanded(
                        child: Text(
                          'Kullanım Şartları ve Gizlilik Politikasını kabul ediyorum.',
                          style: TextStyle(
                            fontSize: width * 0.038,
                            color: textSec,
                          ),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: height * 0.025),
                  SizedBox(
                    width: double.infinity,
                    height: height * 0.065,
                    child: ElevatedButton(
                      onPressed: _agreed
                          ? () async {
                              final String? errorMessage = await _authService
                                  .signUpWithEmailAndPassword(
                                    _emailController.text.trim(),
                                    _passwordController.text.trim(),
                                    _adSoyadController.text.trim(),
                                    _telefonController.text.trim(),
                                  );
                              if (mounted) {
                                if (errorMessage == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Kayıt başarıyla oluşturuldu!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) => const GirisEkrani(),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Kayıt başarısız: $errorMessage',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Kayıt Ol',
                        style: TextStyle(
                          fontSize: width * 0.05,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: height * 0.025),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Zaten bir hesabın var mı?',
                        style: TextStyle(
                          fontSize: width * 0.042,
                          color: textSec,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const GirisEkrani(),
                            ),
                          );
                        },
                        child: Text(
                          'Giriş Yap',
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
