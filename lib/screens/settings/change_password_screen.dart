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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          'Şifre Değiştir',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A202C),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFF7F8FC),
        iconTheme: const IconThemeData(color: Color(0xFF1A202C)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              'Güvenliğiniz için lütfen mevcut şifrenizi ve yeni şifrenizi girin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4.0,
              shadowColor: Colors.black.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
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
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green.shade600),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: toggleVisibility,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _changePassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white),
              )
            : const Text('Şifreyi Güncelle'),
      ),
    );
  }
}
