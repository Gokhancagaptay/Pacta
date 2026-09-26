import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../services/auth_service.dart';
import '../ledger/application/providers.dart';
import '../ledger/data/ledger_repository.dart';

typedef Reauthenticate = Future<String?> Function({String? password});

/// Hesap silme (Apple/Google şartı). Ne silineceğini ve karşı tarafta neyin
/// kalacağını önceden açıkça söyler; geri alınamayacağı onaylanır ve
/// kimlik yeniden doğrulanır.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({
    super.key,
    this.passwordUser,
    this.reauthenticate,
    this.signOut,
  });

  /// Testler için; verilmezse gerçek AuthService kullanılır.
  final bool? passwordUser;
  final Reauthenticate? reauthenticate;
  final Future<void> Function()? signOut;

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  final _password = TextEditingController();
  bool _understood = false;
  bool _busy = false;
  String? _error;

  AuthService? _authService;
  AuthService get _auth => _authService ??= AuthService();

  bool get _isPasswordUser => widget.passwordUser ?? _auth.isPasswordUser;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final reauth = widget.reauthenticate ?? _auth.reauthenticate;
    final authError = await reauth(
      password: _isPasswordUser ? _password.text : null,
    );
    if (!mounted) return;
    if (authError != null) {
      setState(() {
        _busy = false;
        _error = authError;
      });
      return;
    }
    try {
      await ref.read(ledgerRepositoryProvider).deleteAccount();
    } on LedgerException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await (widget.signOut ?? _auth.signOut)();
    navigator.popUntil((route) => route.isFirst);
    messenger.showSnackBar(
      const SnackBar(content: Text('Hesabınız silindi. Görüşmek üzere.')),
    );
    // Sayfa en alttaysa kapanmaz; yükleniyor durumunda kalmasın.
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final uid = ref.watch(currentUidProvider);
    final ledgers = ref.watch(ledgersProvider).valueOrNull ?? const [];
    final withBalance = ledgers
        .where((l) => !l.isPrivate && l.balancesFor(uid).isNotEmpty)
        .length;

    Widget section(String title, List<String> lines, {Color? color}) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(height: 6),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(color: c.muted)),
                  Expanded(child: Text(line, style: const TextStyle(height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Hesabı sil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          section('Silinecekler', const [
            'Profiliniz, e-posta ve telefon bilginiz',
            'Uygulaması olmayan kişiler için tuttuğunuz özel defterler ve '
                'içindeki kayıtlar',
            'Pacta kodunuz, bildirimleriniz ve giriş hesabınız',
          ], color: c.debt),
          section('Karşı tarafta kalacaklar', const [
            'Ortak defterlerdeki onaylı kayıtlar karşı tarafın da kaydıdır; '
                'onun nüshası olarak saklanır.',
            'Bu kayıtlarda adınız "Silinmiş kullanıcı" olarak görünür, '
                'e-postanız kaldırılır.',
            'Bu defterlere artık yeni kayıt eklenemez.',
          ]),
          section('Kapanacaklar', const [
            'Onay bekleyen kayıtlar kapatılır: sizin önerileriniz geri '
                'çekilir, sizin onayınızı bekleyenler reddedilir.',
          ]),
          if (withBalance > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.pendingSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$withBalance kişiyle açık bakiyeniz var. Hesabı silmek borcu '
                'ya da alacağı ortadan kaldırmaz; karşı taraf kendi kaydında '
                'görmeye devam eder.',
                style: TextStyle(color: c.pending),
              ),
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _understood,
            onChanged: _busy ? null : (v) => setState(() => _understood = v ?? false),
            title: const Text('Bu işlemin geri alınamayacağını anlıyorum.'),
          ),
          const SizedBox(height: 8),
          if (_isPasswordUser)
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Şifreniz',
                helperText: 'Güvenlik için şifrenizi yeniden girin.',
              ),
            )
          else
            Text(
              'Devam edince güvenlik için Google hesabınızı yeniden seçmeniz '
              'istenecek.',
              style: TextStyle(color: c.muted),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: c.debt,
              foregroundColor: Colors.white,
            ),
            onPressed: !_understood || _busy ? null : _delete,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Hesabımı kalıcı olarak sil'),
          ),
        ],
      ),
    );
  }
}
