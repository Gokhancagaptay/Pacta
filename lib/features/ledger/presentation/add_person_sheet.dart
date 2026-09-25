import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/ui/widgets.dart';
import '../application/providers.dart';
import '../data/ledger_repository.dart';
import '../domain/pacta_code.dart';
import 'contacts_ui.dart';

/// Kişi ekler; açılan (ya da zaten var olan) defterin kimliğini döner.
Future<String?> showAddPersonSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddPersonSheet(),
    );

/// Hızlı yollar üstte (QR, kodum, davet); altta e-posta ya da kod ile ekleme
/// ve uygulaması olmayanlar için özel defter. Hatalar panelin içinde yazar.
class AddPersonSheet extends ConsumerStatefulWidget {
  const AddPersonSheet({super.key});

  @override
  ConsumerState<AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends ConsumerState<AddPersonSheet> {
  final _query = TextEditingController();
  final _name = TextEditingController();
  String? _queryError;
  String? _nameError;
  bool _busy = false;

  /// Kodla bulunan kişi; eklemeden önce onay için gösterilir.
  ({String code, String name})? _found;

  @override
  void dispose() {
    _query.dispose();
    _name.dispose();
    super.dispose();
  }

  LedgerRepository get _repo => ref.read(ledgerRepositoryProvider);

  void _fail(String message) => setState(() {
    _busy = false;
    _queryError = message;
  });

  void _done(AddedPerson added) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(added.ledgerId);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          added.created
              ? '${added.name} eklendi.'
              : '${added.name} zaten listenizde.',
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final text = _query.text.trim();
    if (text.isEmpty) {
      _fail('E-posta adresi ya da Pacta kodu girin.');
      return;
    }
    setState(() {
      _busy = true;
      _queryError = null;
      _found = null;
    });
    try {
      if (text.contains('@')) {
        final added = await _repo.addByEmail(text);
        if (mounted) _done(added);
        return;
      }
      final code = parsePactaCode(text);
      if (code == null) {
        _fail(
          'Bu bir e-posta ya da Pacta kodu değil. Kod 6 karakterdir '
          '(ör. K7Q-3XM).',
        );
        return;
      }
      await _preview(code);
    } on LedgerException catch (e) {
      if (mounted) _fail(e.message);
    }
  }

  Future<void> _preview(String code) async {
    final preview = await _repo.previewCode(code);
    if (!mounted) return;
    if (preview.self) {
      _fail(
        'Bu sizin kodunuz. Arkadaşınızın kodunu girin ya da ona kendi '
        'kodunuzu okutun.',
      );
      return;
    }
    setState(() {
      _busy = false;
      _found = (code: code, name: preview.name);
    });
  }

  Future<void> _addFound() async {
    final found = _found;
    if (found == null) return;
    setState(() => _busy = true);
    try {
      final added = await _repo.addByCode(found.code);
      if (mounted) _done(added);
    } on LedgerException catch (e) {
      if (mounted) _fail(e.message);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScanCodePage()));
    if (code == null || !mounted) return;
    _query.text = formatPactaCode(code);
    setState(() {
      _busy = true;
      _queryError = null;
    });
    try {
      await _preview(code);
    } on LedgerException catch (e) {
      if (mounted) _fail(e.message);
    }
  }

  Future<void> _openPrivate() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Bir ad girin.');
      return;
    }
    setState(() {
      _busy = true;
      _nameError = null;
    });
    try {
      final ledgerId = await _repo.openPrivateLedger(name);
      if (mounted) Navigator.of(context).pop(ledgerId);
    } on LedgerException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _nameError = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final text = Theme.of(context).textTheme;
    final found = _found;

    Widget quick(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: Material(
        color: c.creditSoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _busy ? null : onTap,
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: c.credit),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.credit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Kişi ekle',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Pacta kullanan biriyle ortak defter açın; kayıtları o da onaylar.',
              style: TextStyle(color: c.muted),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                quick(Icons.qr_code_scanner_rounded, 'QR okut', _scan),
                const SizedBox(width: 8),
                quick(
                  Icons.qr_code_2_rounded,
                  'Kodumu göster',
                  () => openPactaCodePage(context),
                ),
                const SizedBox(width: 8),
                quick(
                  Icons.share_rounded,
                  'Davet et',
                  () => shareInvite(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _query,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'E-posta ya da Pacta kodu',
                hintText: 'ornek@mail.com ya da K7Q-3XM',
                errorText: _queryError,
                errorMaxLines: 4,
              ),
              onChanged: (_) {
                if (_found != null || _queryError != null) {
                  setState(() {
                    _found = null;
                    _queryError = null;
                  });
                }
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 10),
            if (found != null)
              SurfaceCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    PersonAvatar(name: found.name, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        found.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    FilledButton(
                      // Tema düğmeleri tam genişlik; satır içinde sınırlanır.
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(96, 44),
                      ),
                      onPressed: _busy ? null : _addFound,
                      child: const Text('Ekle'),
                    ),
                  ],
                ),
              )
            else
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Bul ve ekle'),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('veya', style: TextStyle(color: c.muted)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Uygulaması olmayan biri',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Özel defteri yalnızca siz görürsünüz; kayıtlar onaysız işlenir. '
              'İsterseniz kişiye davet de gönderebilirsiniz.',
              style: TextStyle(color: c.muted),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Ad soyad',
                errorText: _nameError,
              ),
              onSubmitted: (_) => _openPrivate(),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _busy ? null : _openPrivate,
              child: const Text('Özel defter aç'),
            ),
          ],
        ),
      ),
    );
  }
}
