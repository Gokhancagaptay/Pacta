import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/screens/auth/auth_widgets.dart';
import 'package:pacta/services/auth_service.dart';

/// Şifre değiştirme (yalnızca e-posta/şifre hesapları).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await AuthService().changePassword(_current.text, _next.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    TextInput.finishAutofillContext();
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Şifreniz değiştirildi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şifre değiştir')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'Önce mevcut şifrenizi girin.',
                  style: TextStyle(color: context.pacta.muted),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _current,
                  enabled: !_busy,
                  label: 'Mevcut şifre',
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Mevcut şifrenizi girin.' : null,
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _next,
                  enabled: !_busy,
                  label: 'Yeni şifre',
                  helperText: 'En az $minPasswordLength karakter.',
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final error = validateNewPassword(v);
                    if (error != null) return error;
                    return v == _current.text
                        ? 'Yeni şifre mevcut şifreyle aynı olamaz.'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _repeat,
                  enabled: !_busy,
                  label: 'Yeni şifre (tekrar)',
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _submit(),
                  validator: (v) =>
                      v != _next.text ? 'Şifreler eşleşmiyor.' : null,
                ),
                const SizedBox(height: 24),
                if (_error != null) FormErrorBox(_error!),
                BusyButton(
                  label: 'Şifreyi değiştir',
                  busy: _busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
