import 'package:flutter/material.dart';
import 'package:pacta/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _authService.changePassword(
          _currentPasswordController.text,
          _newPasswordController.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifreniz başarıyla değiştirildi!')),
        );
        Navigator.of(context).pop();
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.message ?? 'Bir hata oluştu.'}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Bir hata oluştu: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF181A20) : const Color(0xFFF7F8FC);
    final textMain = isDark ? Colors.white : const Color(0xFF1A202C);
    final cardColor = isDark ? const Color(0xFF23262F) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Şifre Değiştir',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textMain,
            fontSize: size.width * 0.05,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textMain),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(size.width * 0.04),
        child: Column(
          children: [
            SizedBox(height: size.height * 0.03),
            Text(
              'Güvenliğiniz için lütfen mevcut şifrenizi ve yeni şifrenizi girin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: size.width * 0.038,
              ),
            ),
            SizedBox(height: size.height * 0.03),
            Card(
              elevation: 4.0,
              shadowColor: Colors.black.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(size.width * 0.04),
              ),
              color: cardColor,
              child: Padding(
                padding: EdgeInsets.all(size.width * 0.04),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildPasswordTextField(
                        controller: _currentPasswordController,
                        label: 'Mevcut Şifre',
                        icon: Icons.lock_outline,
                        isVisible: _isCurrentPasswordVisible,
                        toggleVisibility: () => setState(
                          () => _isCurrentPasswordVisible =
                              !_isCurrentPasswordVisible,
                        ),
                        validator: (value) => value!.isEmpty
                            ? 'Lütfen mevcut şifrenizi girin'
                            : null,
                      ),
                      SizedBox(height: size.height * 0.02),
                      _buildPasswordTextField(
                        controller: _newPasswordController,
                        label: 'Yeni Şifre',
                        icon: Icons.lock_open_outlined,
                        isVisible: _isNewPasswordVisible,
                        toggleVisibility: () => setState(
                          () => _isNewPasswordVisible = !_isNewPasswordVisible,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen yeni şifrenizi girin';
                          }
                          if (value.length < 6) {
                            return 'Şifre en az 6 karakter olmalıdır';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: size.height * 0.02),
                      _buildPasswordTextField(
                        controller: _confirmPasswordController,
                        label: 'Yeni Şifre (Tekrar)',
                        icon: Icons.lock_reset_outlined,
                        isVisible: _isConfirmPasswordVisible,
                        toggleVisibility: () => setState(
                          () => _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible,
                        ),
                        validator: (value) {
                          if (value != _newPasswordController.text) {
                            return 'Şifreler eşleşmiyor';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildUpdateButton(),
    );
  }

  Widget _buildPasswordTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isVisible,
    required VoidCallback toggleVisibility,
    required FormFieldValidator<String> validator,
  }) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF2D3748) : Colors.white;

    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: Colors.green.shade600,
          size: size.width * 0.06,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: size.width * 0.06,
          ),
          onPressed: toggleVisibility,
        ),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(size.width * 0.03),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        size.width * 0.04,
        size.width * 0.04,
        size.width * 0.04,
        MediaQuery.of(context).padding.bottom + size.height * 0.02,
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _changePassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, size.height * 0.065),
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontSize: size.width * 0.04,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: _isLoading
            ? SizedBox(
                height: size.width * 0.06,
                width: size.width * 0.06,
                child: const CircularProgressIndicator(color: Colors.white),
              )
            : const Text('Şifreyi Güncelle'),
      ),
    );
  }
}
