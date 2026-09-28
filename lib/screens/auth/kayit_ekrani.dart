import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/core/legal.dart';
import 'package:pacta/screens/auth/auth_widgets.dart';
import 'package:pacta/services/auth_service.dart';

/// E-postayla kayıt. Başarılı kayıttan sonra en alttaki sayfaya dönülür;
/// AuthWrapper e-posta doğrulama ekranını gösterir.
class KayitEkrani extends StatefulWidget {
  const KayitEkrani({super.key});

  @override
  State<KayitEkrani> createState() => _KayitEkraniState();
}

class _KayitEkraniState extends State<KayitEkrani> {
  late final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      setState(
        () => _error =
            'Devam etmek için Kullanım Koşulları\'nı kabul '
            'edin.',
      );
      return;
    }
    TextInput.finishAutofillContext();
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await _auth.signUpWithEmailAndPassword(
      _email.text.trim(),
      _password.text,
      _name.text.trim(),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    return AuthScaffold(
      appBar: AppBar(),
      children: [
        const AuthHeader(
          showMark: false,
          title: 'Hesap oluşturun',
          subtitle:
              'Kayıttan sonra e-postanıza bir doğrulama bağlantısı '
              'gelecek.',
        ),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  maxLength: 80,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Adınızı girin.' : null,
                  decoration: const InputDecoration(
                    labelText: 'Ad soyad',
                    helperText: 'Kayıt tuttuğunuz kişiler bu adı görür.',
                    counterText: '',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: validateEmail,
                  decoration: const InputDecoration(
                    labelText: 'E-posta',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _password,
                  enabled: !_busy,
                  label: 'Şifre',
                  helperText: 'En az $minPasswordLength karakter.',
                  autofillHints: const [AutofillHints.newPassword],
                  validator: validateNewPassword,
                  onSubmitted: (_) => _signUp(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _busy ? null : () => setState(() => _agreed = !_agreed),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _agreed = v ?? false),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    "Kullanım Koşulları'nı okudum ve kabul ediyorum. 18 "
                    'yaşından büyüğüm.',
                  ),
                ),
              ],
            ),
          ),
        ),
        // Aydınlatma metni onaya bağlanmaz; okunmak üzere sunulur.
        Wrap(
          spacing: 4,
          children: [
            for (final page in [LegalPage.terms, LegalPage.privacy])
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                ),
                onPressed: () => openLegalPage(context, page),
                child: Text(page.title),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null) FormErrorBox(_error!),
        BusyButton(label: 'Hesap oluştur', busy: _busy, onPressed: _signUp),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Zaten hesabınız var mı?', style: TextStyle(color: c.muted)),
            TextButton(
              // Kayıt ekranı giriş ekranının üstünde açılır.
              onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
              child: const Text('Giriş yapın'),
            ),
          ],
        ),
      ],
    );
  }
}
