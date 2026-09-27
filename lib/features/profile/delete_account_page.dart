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
    this.isUserGone,
  });

  /// Testler için; verilmezse gerçek AuthService kullanılır.
  final bool? passwordUser;
  final Reauthenticate? reauthenticate;
  final Future<void> Function()? signOut;
  final Future<bool> Function()? isUserGone;

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
    // Sayfa kapansa bile silme sonrası çıkış yapılabilsin diye önceden alınır.
    final signOut = widget.signOut ?? _auth.signOut;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final reauth = widget.reauthenticate ?? _auth.reauthenticate;
    final authError = await reauth(
      password: _isPasswordUser ? _password.text : null,
    );
    if (authError != null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = authError;
        });
      }
      return;
    }

    var deleted = false;
    String? error;
    try {
      await ref.read(ledgerRepositoryProvider).deleteAccount();
      deleted = true;
    } on LedgerException catch (e) {
      error = e.needsReauth
          ? 'Güvenlik süresi doldu. Tekrar deneyin; kimliğiniz yeniden '
                'doğrulanacak.'
          : e.message;
      // Bağlantı sunucu işi bitirdikten sonra koptuysa hesap zaten silinmiş
      // olabilir: cihazda oturum bırakılmaz.
      deleted = await (widget.isUserGone ?? _auth.isCurrentUserGone)();
    }

    if (!deleted) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
      return;
    }
    // Hesap silindi: oturum her durumda kapanır (sayfa kapanmış olsa bile).
    await signOut();
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
        .where(
          (l) => !l.isPrivate && !l.isClosed && l.balancesFor(uid).isNotEmpty,
        )
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
                  Expanded(
                    child: Text(line, style: const TextStyle(height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    // Silme sürerken geri çıkılamaz (yarıda bırakılıp oturum açık kalmasın).
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Hesabı sil')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Metinler functions/src/ledger/account.ts ile birebir uyumludur.
            section('Silinecekler', const [
              'Profiliniz, e-posta ve telefon bilginiz',
              'Uygulaması olmayan kişiler için tuttuğunuz özel defterler ve '
                  'içindeki kayıtlar',
              'Pacta kodunuz, bildirimleriniz, bekleyen hatırlatmalarınız ve '
                  'giriş hesabınız',
            ], color: c.debt),
            section('Karşı tarafta kalacaklar', const [
              'Ortak defterlerdeki tüm kayıtlar ve geçmişi (düzeltmeler, onay '
                  've itiraz notları dahil) karşı tarafın da kaydıdır; onun '
                  'nüshası olarak saklanır.',
              'Bu defterlerde adınız "Silinmiş kullanıcı" olarak görünür, '
                  'e-postanız kaldırılır. Karşı tarafın daha önce aldığı '
                  'bildirimlerde ve kayıt açıklamalarında adınız geçebilir.',
              'Karşı taraf, hesabınızı sildiğiniz konusunda bilgilendirilir.',
              'Bu defterlere artık yeni kayıt eklenemez. Kayıtlar 10 yıl '
                  'sonra otomatik silinir; karşı taraf da hesabını silmişse '
                  'ortak defter hemen tamamen silinir.',
            ]),
            section('Kapanacaklar', const [
              'Açık kayıtlar kapatılır: sizin önerileriniz geri çekilir, '
                  'karşı tarafın açık kayıtları reddedilir.',
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
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _understood = v ?? false),
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
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Hesabımı kalıcı olarak sil'),
            ),
          ],
        ),
      ),
    );
  }
}
