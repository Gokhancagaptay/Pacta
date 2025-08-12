// lib/screens/auth/kayit_ekrani.dart

import 'package:flutter/material.dart';
import 'package:pacta/screens/auth/giris_ekrani.dart';
import 'package:pacta/services/auth_service.dart';
import 'package:pacta/constants/strings.dart';

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
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const GirisEkrani()),
            );
          },
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
      // Kayıt oluşturuldu, doğrulama bekleniyor
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          final size = MediaQuery.of(ctx).size;
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textMain = isDark ? Colors.white : const Color(0xFF111827);
          final textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
          final green = const Color(0xFF4ADE80);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: size.width * 0.06,
              right: size.width * 0.06,
              top: size.height * 0.02,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.02),
                Text(
                  AppStrings.verifyEmailSheetTitle,
                  style: TextStyle(
                    fontSize: size.width * 0.06,
                    fontWeight: FontWeight.bold,
                    color: textMain,
                  ),
                ),
                SizedBox(height: size.height * 0.008),
                Text(
                  AppStrings.verifyEmailSheetDesc,
                  style: TextStyle(fontSize: size.width * 0.04, color: textSec),
                ),
                SizedBox(height: size.height * 0.025),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _authService.sendVerificationEmail();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Doğrulama e-postası tekrar gönderildi.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Maili Yeniden Gönder'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: size.height * 0.02),
                StatefulBuilder(
                  builder: (ctx, setSheetState) {
                    bool isSubmitting = false;
                    bool autoStarted = false;

                    void startAutoCheck() {
                      if (autoStarted) return;
                      autoStarted = true;
                      Future<void>(() async {
                        for (int i = 0; i < 8; i++) {
                          await Future.delayed(const Duration(seconds: 2));
                          final ok = await _authService
                              .finalizeUserAfterEmailVerification(
                                adSoyad: _adSoyadController.text.trim(),
                                telefon: _telefonController.text.trim(),
                              );
                          if (!mounted) return;
                          if (ok) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'E-posta doğrulandı. Giriş yapabilirsiniz.',
                                ),
                              ),
                            );
                            await _authService.signOut();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const GirisEkrani(),
                              ),
                            );
                            return;
                          }
                        }
                      });
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      startAutoCheck();
                    });
                    Future<void> handleSubmit() async {
                      if (isSubmitting) return;
                      setSheetState(() => isSubmitting = true);
                      FocusScope.of(context).unfocus();
                      final ok = await _authService
                          .finalizeUserAfterEmailVerification(
                            adSoyad: _adSoyadController.text.trim(),
                            telefon: _telefonController.text.trim(),
                          );
                      if (!mounted) return;
                      if (ok) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'E-posta doğrulandı. Giriş yapabilirsiniz.',
                            ),
                          ),
                        );
                        await _authService.signOut();
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const GirisEkrani(),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Doğrulama tespit edilemedi. Lütfen e-postanızı kontrol edin.',
                            ),
                          ),
                        );
                      }
                      setSheetState(() => isSubmitting = false);
                    }

                    return SizedBox(
                      width: double.infinity,
                      height: size.height * 0.06,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              size.width * 0.035,
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? SizedBox(
                                height: size.width * 0.05,
                                width: size.width * 0.05,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                AppStrings.iVerified,
                                style: TextStyle(
                                  fontSize: size.width * 0.045,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    );
                  },
                ),
                SizedBox(height: size.height * 0.02),
              ],
            ),
          );
        },
      );
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
