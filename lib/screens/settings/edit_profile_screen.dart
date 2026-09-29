import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pacta/core/report.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/core/ui/widgets.dart';
import 'package:pacta/models/user_model.dart';
import 'package:pacta/screens/auth/auth_widgets.dart';
import 'package:pacta/services/firestore_service.dart';

/// Adı düzenler. E-posta giriş kimliğidir, değiştirilemez (firestore.rules).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.adSoyad ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _name.text.trim();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (name == (widget.user.adSoyad ?? '').trim()) {
      navigator.pop();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirestoreService()
          .updateUser(widget.user.uid, {'adSoyad': name})
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Adınız güncellendi.')),
      );
    } on TimeoutException {
      // İnternet yok: yazım cihazda bekler, bağlantı gelince gider.
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('İnternet gelince adınız kaydedilecek.')),
      );
    } catch (e, st) {
      reportError(e, st, reason: 'Profil kaydedilemedi');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'Kaydedilemedi. İnternet bağlantınızı kontrol edip tekrar '
            'deneyin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    return Scaffold(
      appBar: AppBar(title: const Text('Profili düzenle')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Center(
              child: ValueListenableBuilder(
                valueListenable: _name,
                builder: (_, value, _) => PersonAvatar(
                  name: value.text.trim().isEmpty ? '?' : value.text,
                  size: 72,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _name,
                enabled: !_busy,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                maxLength: 80,
                onFieldSubmitted: (_) => _save(),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Adınızı girin.' : null,
                decoration: const InputDecoration(
                  labelText: 'Ad soyad',
                  helperText: 'Kayıt tuttuğunuz kişiler bu adı görür.',
                  counterText: '',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.mail_outline_rounded, size: 18, color: c.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.user.email} · giriş adresiniz, değiştirilemez',
                    style: TextStyle(color: c.muted, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_error != null) FormErrorBox(_error!),
            BusyButton(label: 'Kaydet', busy: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
