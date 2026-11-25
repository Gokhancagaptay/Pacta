import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/core/legal.dart';
import 'package:pacta/screens/auth/auth_widgets.dart';
import 'package:pacta/screens/auth/kayit_ekrani.dart';
import 'package:pacta/services/auth_service.dart';

/// Giriş: e-posta/şifre ya da Google. Başarılı girişten sonra hangi ekranın
/// açılacağına AuthWrapper karar verir (doğrulama, koşullar, ana ekran).
class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  late final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await action();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      _busy = false;
      // Hesap seçiminden vazgeçmek hata değildir.
      _error = error == AuthService.googleCancelled ? null : error;
    });
  }

  void _signIn() {
    if (!_formKey.currentState!.validate()) return;
    TextInput.finishAutofillContext();
    _run(
      () =>
          _auth.signInWithEmailAndPassword(_email.text.trim(), _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    return AuthScaffold(
      children: [
        const AuthHeader(
          title: 'Giriş yapın',
          subtitle: 'Borç ve alacaklarınızı karşı tarafla birlikte tutun.',
        ),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  onSubmitted: (_) => _signIn(),
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Şifrenizi girin.' : null,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : _showResetSheet,
            child: const Text('Şifremi unuttum'),
          ),
        ),
        const SizedBox(height: 8),
        if (_error != null) FormErrorBox(_error!),
        BusyButton(label: 'Giriş yap', busy: _busy, onPressed: _signIn),
        const OrDivider(),
        GoogleButton(onPressed: _busy ? null : () => _run(_auth.googleSignIn)),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Hesabınız yok mu?', style: TextStyle(color: c.muted)),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const KayitEkrani(),
                      ),
                    ),
              child: const Text('Kayıt olun'),
            ),
          ],
        ),
        // Google ile ilk girişte ad ve e-posta burada alınır; aydınlatma
        // metni girişten önce erişilebilir olmalı.
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (final page in [LegalPage.privacy, LegalPage.terms])
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: c.muted,
                  textStyle: Theme.of(context).textTheme.bodySmall,
                ),
                onPressed: () => openLegalPage(context, page),
                child: Text(page.title),
              ),
          ],
        ),
      ],
    );
  }

  void _showResetSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _ResetPasswordSheet(initialEmail: _email.text.trim(), auth: _auth),
    );
  }
}

class _ResetPasswordSheet extends StatefulWidget {
  const _ResetPasswordSheet({required this.initialEmail, required this.auth});

  final String initialEmail;
  final AuthService auth;

  @override
  State<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<_ResetPasswordSheet> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final error = await widget.auth.sendPasswordResetEmail(_email.text.trim());
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Bağlantı gönderildi. Gelen kutunuzu (ve gereksiz klasörünü) '
          'kontrol edin.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Şifrenizi sıfırlayın',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Hesabınızın e-posta adresine yeni şifre belirleme bağlantısı '
              'göndereceğiz.',
              style: TextStyle(color: context.pacta.muted),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _email,
              enabled: !_busy,
              autofocus: widget.initialEmail.isEmpty,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.send,
              onFieldSubmitted: (_) => _send(),
              validator: validateEmail,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) FormErrorBox(_error!),
            BusyButton(label: 'Bağlantı gönder', busy: _busy, onPressed: _send),
          ],
        ),
      ),
    );
  }
}
