import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/auth_service.dart';

/// E-postası doğrulanmamış hesap burada bekler. Bağlantıya dokunup dönünce
/// otomatik devam edilir; bağlantı yeniden gönderilebilir ya da başka
/// hesapla girilebilir. Doğrulanmadan uygulamanın içine geçilemez.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, this.auth});

  /// Testler için; verilmezse gerçek servis kullanılır.
  final AuthService? auth;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  late final AuthService _auth = widget.auth ?? AuthService();
  static const _cooldown = 60;
  static const _autoCheckFor = Duration(minutes: 3);

  Timer? _poll;
  Timer? _tick;
  int _wait = 0;
  bool _checking = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // İlk birkaç dakika sessizce kontrol eder; sonra uygulamaya dönüşte ya da
    // düğmeyle kontrol edilir.
    final until = DateTime.now().add(_autoCheckFor);
    _poll = Timer.periodic(const Duration(seconds: 5), (t) {
      if (DateTime.now().isAfter(until)) {
        t.cancel();
        return;
      }
      _check(silent: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(silent: true);
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    _checking = true;
    try {
      // Doğrulandıysa AuthWrapper kullanıcı değişikliğini görüp ana ekrana
      // geçer; burada ayrıca yönlendirme yapılmaz.
      final ok = await _auth.refreshEmailVerified();
      if (!ok && !silent && mounted) {
        _show('Henüz doğrulanmamış görünüyor. E-postadaki bağlantıya dokunup '
            'tekrar deneyin.', error: true);
      }
    } catch (_) {
      if (!silent && mounted) {
        _show('Kontrol edilemedi. İnternet bağlantınızı kontrol edin.',
            error: true);
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _resend() async {
    final error = await _auth.sendVerificationEmail();
    if (!mounted) return;
    if (error != null) {
      _show(error, error: true);
      return;
    }
    _show('Doğrulama bağlantısı tekrar gönderildi. Gereksiz (spam) klasörünü '
        'de kontrol edin.');
    setState(() => _wait = _cooldown);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  void _show(String message, {bool error = false}) => setState(() {
    _message = message;
    _messageIsError = error;
  });

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final text = Theme.of(context).textTheme;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: c.creditSoft,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(Icons.mark_email_unread_outlined, size: 36, color: c.credit),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'E-postanızı doğrulayın',
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              '$email adresine bir doğrulama bağlantısı gönderdik. Bağlantıya '
              'dokunup uygulamaya dönün; otomatik olarak devam edeceğiz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Doğrulama, başkasının e-posta adresiyle hesap açılmasını önler.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.muted),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => _check(),
              child: const Text('Doğruladım, devam et'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _wait > 0 ? null : _resend,
              child: Text(
                _wait > 0
                    ? 'Tekrar göndermek için $_wait sn'
                    : 'Bağlantıyı tekrar gönder',
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _messageIsError
                      ? Theme.of(context).colorScheme.error
                      : c.credit,
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => _auth.signOut(),
              child: const Text('Farklı hesapla giriş yap'),
            ),
          ],
        ),
      ),
    );
  }
}
