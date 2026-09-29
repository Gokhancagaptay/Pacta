import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Giriş, kayıt ve şifre ekranlarının ortak parçaları: temadan beslenir,
/// geniş ekranda (tablet, web) form ortada dar bir sütunda durur.

/// Ortalanmış, kaydırılabilir, en fazla 440 px genişlikte içerik.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.children, this.appBar});

  final List<Widget> children;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marka işareti, başlık ve kısa açıklama.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showMark = true,
  });

  final String title;
  final String subtitle;
  final bool showMark;

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showMark) ...[const PactaMark(), const SizedBox(height: 24)],
        Text(
          title,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: c.muted, height: 1.4)),
        const SizedBox(height: 28),
      ],
    );
  }
}

/// Uygulamanın işareti: yeşil zemin üstünde el sıkışma.
class PactaMark extends StatelessWidget {
  const PactaMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: PactaTheme.brandFill,
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Icon(
            Icons.handshake_rounded,
            color: PactaTheme.onBrandFill,
            size: size * 0.55,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Pacta',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Formun altında, düğmenin üstünde duran hata kutusu. Bildirim şeridi
/// gibi kaybolmaz; kullanıcı okuyup düzeltir.
class FormErrorBox extends StatelessWidget {
  const FormErrorBox(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    // Canlı bölge: hata çıkınca ekran okuyucu kendiliğinden okur.
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.debtSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: c.debt, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: c.debt, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ana düğme; işlem sürerken yerinde dönen gösterge.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Text(label),
    );
  }
}

class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
      onPressed: onPressed,
      icon: Image.asset('assets/google_logo.png', width: 20, height: 20),
      label: const Text('Google ile devam et'),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('veya', style: TextStyle(color: context.pacta.muted)),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

/// Şifre alanı: göster/gizle düğmesiyle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.helperText,
    this.autofillHints = const [AutofillHints.password],
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final String? helperText;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Şifreyi göster' : 'Şifreyi gizle',
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    );
  }
}

/// Basit biçim denetimi; asıl kontrol Firebase'dedir.
String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'E-posta adresinizi girin.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
    return 'Geçerli bir e-posta adresi girin.';
  }
  return null;
}

/// Yeni şifreler için en az uzunluk.
const minPasswordLength = 8;

String? validateNewPassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Bir şifre belirleyin.';
  if (v.length < minPasswordLength) {
    return 'Şifre en az $minPasswordLength karakter olmalı.';
  }
  return null;
}
