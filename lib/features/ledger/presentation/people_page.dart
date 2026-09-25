import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../services/firestore_service.dart';
import '../application/providers.dart';
import 'common.dart';

/// Tüm defterler (kişiler), son hareket sırasıyla.
class PeoplePage extends ConsumerWidget {
  const PeoplePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgers = ref.watch(ledgersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kişiler'),
        actions: [
          IconButton(
            tooltip: 'Kişi ekle',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => _add(context),
          ),
        ],
      ),
      body: ledgers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Kişiler yüklenemedi.',
          onRetry: () => ref.invalidate(ledgersProvider),
        ),
        data: (list) => list.isEmpty
            ? Center(
                child: EmptyState(
                  icon: Icons.people_alt_rounded,
                  title: 'Henüz kimse yok',
                  message:
                      'Borç ya da alacak takip ettiğiniz kişileri ekleyin. '
                      'Kayıtlar karşı taraf onaylayınca bakiyeye işlenir.',
                  action: FilledButton(
                    onPressed: () => _add(context),
                    child: const Text('Kişi ekle'),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                children: [
                  SurfaceCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < list.length; i++)
                          LedgerTile(
                            ledger: list[i],
                            showDivider: i < list.length - 1,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final id = await showAddPersonSheet(context);
    if (id != null && context.mounted) openLedger(context, id);
  }
}

/// Kişi ekler; açılan (ya da zaten var olan) defterin kimliğini döner.
Future<String?> showAddPersonSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddPersonSheet(),
    );

class _AddPersonSheet extends ConsumerStatefulWidget {
  const _AddPersonSheet();

  @override
  ConsumerState<_AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends ConsumerState<_AddPersonSheet> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  String? _emailError;
  String? _nameError;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _findByEmail() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _emailError = 'Geçerli bir e-posta adresi girin.');
      return;
    }
    setState(() {
      _busy = true;
      _emailError = null;
    });
    final user = await FirestoreService().getUserByEmail(email);
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _busy = false;
        _emailError =
            'Bu e-postayla kayıtlı bir kullanıcı yok. Aşağıdan özel defter '
            'açabilirsiniz.';
      });
      return;
    }
    if (user.uid == ref.read(currentUidProvider)) {
      setState(() {
        _busy = false;
        _emailError = 'Bu sizin hesabınız.';
      });
      return;
    }
    String? ledgerId;
    await runCommand(context, () async {
      ledgerId = await ref.read(ledgerRepositoryProvider).openSharedLedger(user.uid);
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ledgerId != null) Navigator.of(context).pop(ledgerId);
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
    String? ledgerId;
    await runCommand(context, () async {
      ledgerId = await ref.read(ledgerRepositoryProvider).openPrivateLedger(name);
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ledgerId != null) Navigator.of(context).pop(ledgerId);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final text = Theme.of(context).textTheme;
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
            Text('Kişi ekle', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Pacta kullanan biriyle ortak defter açın; kayıtları o da onaylar.',
              style: TextStyle(color: c.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'E-posta adresi',
                errorText: _emailError,
                errorMaxLines: 3,
              ),
              onSubmitted: (_) => _findByEmail(),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : _findByEmail,
              child: const Text('Bul ve ekle'),
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
              'Özel defteri yalnızca siz görürsünüz; kayıtlar onaysız işlenir.',
              style: TextStyle(color: c.muted),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Ad soyad', errorText: _nameError),
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
