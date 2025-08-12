// lib/screens/auth/giris_ekrani.dart

import 'package:flutter/material.dart';
import 'package:pacta/screens/auth/kayit_ekrani.dart';
import 'package:pacta/services/auth_service.dart';
import 'package:pacta/screens/dashboard/dashboard_screen.dart';
import 'package:pacta/constants/strings.dart';

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordObscured = true;
  final TextEditingController _resetEmailController = TextEditingController();

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
                    AppStrings.loginTitle,
                    style: TextStyle(
                      fontSize: size.width * 0.08,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
                  SizedBox(height: size.height * 0.01),
                  Text(
                    AppStrings.loginSubtitle,
                    style: TextStyle(
                      fontSize: size.width * 0.045,
                      color: textSec,
                    ),
                  ),
                  SizedBox(height: size.height * 0.04),
                  _buildTextField(
                    controller: _emailController,
                    labelText: AppStrings.emailLabel,
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: size.height * 0.02),
                  _buildTextField(
                    controller: _passwordController,
                    labelText: AppStrings.passwordLabel,
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
                  SizedBox(height: size.height * 0.012),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: _showForgotPasswordSheet,
                        child: Text(
                          AppStrings.forgotPassword,
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
                        AppStrings.loginButton,
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
                        AppStrings.loginWithGoogle,
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
                        AppStrings.noAccount,
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
                          AppStrings.registerNow,
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

  void _signIn() async {
    final String? errorMessage = await _authService.signInWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (!mounted) return;
    if (errorMessage == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Giriş başarısız: $errorMessage')));
    }
  }

  void _googleSignIn() async {
    final String? errorMessage = await _authService.googleSignIn();
    if (!mounted) return;
    if (errorMessage == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google ile giriş başarısız: $errorMessage')),
      );
    }
  }

  void _showSnack(String message, {bool isSuccess = true}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? const Color(0xFF16A34A)
            : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showForgotPasswordSheet() {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? Colors.white : const Color(0xFF111827);
    final textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final green = const Color(0xFF4ADE80);

    _resetEmailController.text = _emailController.text.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.015),
                  Text(
                    'Şifre Sıfırlama',
                    style: TextStyle(
                      color: textMain,
                      fontWeight: FontWeight.bold,
                      fontSize: size.width * 0.05,
                    ),
                  ),
                  SizedBox(height: size.height * 0.006),
                  Text(
                    'E-posta doğrulaması tamamlanmış hesabın için sıfırlama bağlantısı göndereceğiz.',
                    style: TextStyle(
                      color: textSec,
                      fontSize: size.width * 0.038,
                    ),
                  ),
                  SizedBox(height: size.height * 0.014),
                  TextField(
                    controller: _resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.014),
                  SizedBox(
                    width: double.infinity,
                    height: size.height * 0.06,
                    child: ElevatedButton(
                      onPressed: isSending
                          ? null
                          : () async {
                              setSheetState(() => isSending = true);
                              final msg = await _authService
                                  .sendPasswordResetEmailIfVerified(
                                    _resetEmailController.text.trim(),
                                  );
                              if (!mounted) return;
                              setSheetState(() => isSending = false);
                              if (msg == null) {
                                Navigator.of(ctx).pop();
                                _showSnack(
                                  'Şifre sıfırlama bağlantısı e-postana gönderildi.',
                                  isSuccess: true,
                                );
                              } else {
                                _showSnack(msg, isSuccess: false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: isSending
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Sıfırlama Bağlantısı Gönder'),
                    ),
                  ),
                  SizedBox(height: size.height * 0.008),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
