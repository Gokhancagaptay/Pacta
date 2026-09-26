import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../profile/profile_providers.dart';
import '../application/providers.dart';
import '../data/ledger_repository.dart';
import '../domain/models.dart';
import '../domain/pacta_code.dart';
import 'common.dart';

/// Kullanıcının Pacta kodu; profilde yoksa sunucu üretir.
final myPactaCodeProvider = FutureProvider.autoDispose<String>((ref) async {
  final known = ref.watch(userProfileProvider).valueOrNull?.pactaCode;
  if (known != null) return known;
  return ref.read(ledgerRepositoryProvider).myPactaCode();
});

/// Davet metnini paylaşım menüsüyle gönderir (WhatsApp, SMS...).
/// [onError] verilirse hata oraya iletilir (ör. açık panelin içinde
/// gösterilir; alttaki bildirim şeridi panelin arkasında kalır).
Future<void> shareInvite(
  BuildContext context,
  WidgetRef ref, {
  void Function(String message)? onError,
}) async {
  try {
    final code = await ref.read(myPactaCodeProvider.future);
    await SharePlus.instance.share(ShareParams(text: inviteText(code)));
  } on LedgerException catch (e) {
    if (onError != null) {
      onError(e.message);
    } else if (context.mounted) {
      showSnack(context, e.message, error: true);
    }
  }
}

void openPactaCodePage(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const PactaCodePage()));

/// Kişinin kodu: QR (arkadaş okutur), yazılı kod, kopyala ve paylaş.
class PactaCodePage extends ConsumerWidget {
  const PactaCodePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pacta;
    final code = ref.watch(myPactaCodeProvider);
    final name = ref.watch(userProfileProvider).valueOrNull?.adSoyad ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Pacta kodum')),
      body: code.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e is LedgerException ? e.message : 'Kod alınamadı.',
          onRetry: () => ref.invalidate(myPactaCodeProvider),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Arkadaşınız bu QR\'ı okutunca ya da kodu girince sizinle ortak '
              'defter açılır.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  // Koyu temada da okunabilsin diye her zaman beyaz.
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.line),
                ),
                child: QrImageView(
                  data: inviteLink(value),
                  size: 220,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'Pacta kodu QR',
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (name.isNotEmpty)
              Text(name, textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
            SelectableText(
              formatPactaCode(value),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: formatPactaCode(value)));
                      showSnack(context, 'Kod kopyalandı.');
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Kopyala'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(text: inviteText(value)),
                    ),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Paylaş'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: c.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kodla eklenen kişi adınızı ve e-postanızı görür. Kodu '
                    'yalnızca hesap tuttuğunuz kişilerle paylaşın.',
                    style: TextStyle(fontSize: 13, color: c.muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// QR okutur; geçerli bir Pacta kodu bulunca kodu döner.
class ScanCodePage extends StatefulWidget {
  const ScanCodePage({super.key});

  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _done = false;
  String? _hint;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = parsePactaCode(barcode.rawValue ?? '');
      if (code != null) {
        _done = true;
        _controller.stop();
        Navigator.of(context).pop(code);
        return;
      }
    }
    if (_hint == null) {
      setState(() => _hint = 'Bu bir Pacta kodu değil. Profil > Pacta kodum '
          'ekranındaki QR\'ı okutun.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR okut')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => EmptyState(
              icon: Icons.no_photography_outlined,
              title: 'Kamera açılamadı',
              message:
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? 'QR okutmak için kamera izni gerekiyor. Ayarlardan izin '
                        'verebilir ya da kodu elle girebilirsiniz.'
                  : 'Kodu elle girebilirsiniz.',
              action: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kodu elle gir'),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 32,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _hint ?? 'Arkadaşınızın Pacta kodum ekranındaki QR\'ı okutun.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linkten ya da QR'dan gelen kod: kişinin adını gösterip onay ister,
/// onaylanırsa ortak defteri açar.
Future<void> confirmAddByCode(
  BuildContext context,
  WidgetRef ref,
  String code,
) async {
  final repo = ref.read(ledgerRepositoryProvider);
  final ({bool self, String name}) preview;
  try {
    preview = await repo.previewCode(code);
  } on LedgerException catch (e) {
    if (context.mounted) showSnack(context, e.message, error: true);
    return;
  }
  if (!context.mounted) return;
  if (preview.self) {
    showSnack(context, 'Bu sizin kodunuz. Arkadaşınızın okutması gerekiyor.');
    return;
  }
  final ok = await showModalBottomSheet<bool>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: PersonAvatar(name: preview.name, size: 56)),
            const SizedBox(height: 12),
            Text(
              preview.name,
              textAlign: TextAlign.center,
              style: Theme.of(sheet).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bu kişiyle ortak defter açılsın mı? Kayıtları o da onaylar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: sheet.pacta.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.of(sheet).pop(true),
              child: const Text('Ekle'),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheet).pop(false),
              child: const Text('Vazgeç'),
            ),
          ],
        ),
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    final added = await repo.addByCode(code);
    if (!context.mounted) return;
    openLedger(context, added.ledgerId);
    showSnack(
      context,
      added.created
          ? '${added.name} eklendi.'
          : '${added.name} zaten listenizde.',
    );
  } on LedgerException catch (e) {
    if (context.mounted) showSnack(context, e.message, error: true);
  }
}

/// Kişi eylemleri: favori, listeden kaldır (ortak) ya da sil (özel).
/// [onDeleted]: defter silinince (ör. açık defter sayfasını kapatmak için).
Future<void> showPersonActions(
  BuildContext context,
  WidgetRef ref,
  Ledger ledger, {
  VoidCallback? onDeleted,
}) async {
  final uid = ref.read(currentUidProvider);
  final repo = ref.read(ledgerRepositoryProvider);
  final name = ledger.other(uid).displayName;
  final favorite = ref.read(favoriteLedgersProvider).contains(ledger.id);

  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: ledger.other(uid).email == null
                ? null
                : Text(ledger.other(uid).email!),
          ),
          ListTile(
            leading: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded),
            title: Text(favorite ? 'Favorilerden çıkar' : 'Favorilere ekle'),
            onTap: () => Navigator.of(sheet).pop('favorite'),
          ),
          if (ledger.isPrivate)
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: sheet.pacta.debt),
              title: Text('Defteri sil', style: TextStyle(color: sheet.pacta.debt)),
              onTap: () => Navigator.of(sheet).pop('delete'),
            )
          else
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Listeden kaldır'),
              subtitle: const Text('Hesap geçmişi silinmez'),
              onTap: () => Navigator.of(sheet).pop('hide'),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case 'favorite':
      await repo.setFavorite(uid, ledger.id, !favorite);
      if (context.mounted) {
        showSnack(
          context,
          favorite ? '$name favorilerden çıkarıldı.' : '$name favorilere eklendi.',
        );
      }
    case 'hide':
      await hidePerson(context, ref, ledger, onHidden: onDeleted);
    case 'delete':
      await deletePrivateLedger(context, ref, ledger, onDeleted: onDeleted);
  }
}

/// Ortak defteri listeden kaldırır (onay ister, geri alınabilir).
Future<void> hidePerson(
  BuildContext context,
  WidgetRef ref,
  Ledger ledger, {
  VoidCallback? onHidden,
}) async {
  final uid = ref.read(currentUidProvider);
  final repo = ref.read(ledgerRepositoryProvider);
  final name = ledger.other(uid).displayName;
  final open = ledger.balancesFor(uid).isNotEmpty || ledger.pendingCount > 0;
  final confirmed = await _confirm(
    context,
    title: 'Listeden kaldırılsın mı?',
    message:
        '$name listenizden kaldırılır. Hesap geçmişi silinmez; $name yeni '
        'bir kayıt eklerse yeniden görünür.'
        '${open ? '\n\nBu kişiyle açık bakiye ya da onay bekleyen kayıt '
                  'var; kaldırmak bunları silmez.' : ''}',
    action: 'Kaldır',
  );
  if (confirmed != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  await repo.setHidden(uid, ledger.id, true);
  onHidden?.call();
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text('$name listeden kaldırıldı.'),
      action: SnackBarAction(
        label: 'Geri al',
        onPressed: () => repo.setHidden(uid, ledger.id, false),
      ),
    ),
  );
}

/// Özel defteri kalıcı olarak siler (onay ister).
Future<void> deletePrivateLedger(
  BuildContext context,
  WidgetRef ref,
  Ledger ledger, {
  VoidCallback? onDeleted,
}) async {
  final uid = ref.read(currentUidProvider);
  final name = ledger.other(uid).displayName;
  final confirmed = await _confirm(
    context,
    title: 'Defter silinsin mi?',
    message:
        '$name özel defteri ve içindeki tüm kayıtlar kalıcı olarak silinir. '
        'Bu işlem geri alınamaz.',
    action: 'Sil',
    destructive: true,
  );
  if (confirmed != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(ledgerRepositoryProvider).deletePrivateLedger(ledger.id);
    onDeleted?.call();
    messenger.showSnackBar(SnackBar(content: Text('$name defteri silindi.')));
  } on LedgerException catch (e) {
    if (context.mounted) showSnack(context, e.message, error: true);
  }
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = false,
}) => showDialog<bool>(
  context: context,
  builder: (dialog) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(dialog).pop(false),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        // Tema düğmeleri tam genişlik; diyalog eylemlerinde sınırlanır.
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, 44),
          backgroundColor: destructive ? dialog.pacta.debt : null,
          foregroundColor: destructive ? Colors.white : null,
        ),
        onPressed: () => Navigator.of(dialog).pop(true),
        child: Text(action),
      ),
    ],
  ),
);

/// Listeden kaldırılanlar; geri getirilebilir.
Future<void> showHiddenPeopleSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const _HiddenPeopleSheet(),
    );

class _HiddenPeopleSheet extends ConsumerWidget {
  const _HiddenPeopleSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final hidden = ref.watch(hiddenLedgersProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text(
              'Listeden kaldırılanlar',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (hidden.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Kaldırılan kimse yok.'),
            ),
          for (final l in hidden)
            ListTile(
              leading: PersonAvatar(name: l.other(uid).displayName, size: 36),
              title: Text(l.other(uid).displayName),
              subtitle: l.other(uid).email == null ? null : Text(l.other(uid).email!),
              trailing: TextButton(
                onPressed: () =>
                    ref.read(ledgerRepositoryProvider).setHidden(uid, l.id, false),
                child: const Text('Geri getir'),
              ),
            ),
        ],
      ),
    );
  }
}
