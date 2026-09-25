import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../services/firestore_service.dart';
import '../application/providers.dart';
import '../domain/summary.dart';
import 'common.dart';

/// Kişiler: kim size, siz kime ne kadar borçlusunuz. Liste ya da tablo;
/// süzgeç, sıralama, arama ve görünen satırların toplamı.
class PeoplePage extends ConsumerWidget {
  const PeoplePage({super.key});

  /// Bu sayıdan fazla kişi varsa arama kutusu görünür.
  static const searchThreshold = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(personRowsProvider);
    final table = ref.watch(peopleTableViewProvider);
    final sort = ref.watch(peopleSortProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kişiler'),
        actions: [
          IconButton(
            tooltip: table ? 'Liste görünümü' : 'Tablo görünümü',
            icon: Icon(table ? Icons.view_agenda_rounded : Icons.table_rows_rounded),
            onPressed: () =>
                ref.read(peopleTableViewProvider.notifier).state = !table,
          ),
          PopupMenuButton<PeopleSort>(
            tooltip: 'Sırala',
            icon: const Icon(Icons.sort_rounded),
            initialValue: sort,
            onSelected: (s) => ref.read(peopleSortProvider.notifier).state = s,
            itemBuilder: (_) => [
              for (final s in PeopleSort.values)
                CheckedPopupMenuItem(value: s, checked: s == sort, child: Text(s.label)),
            ],
          ),
          IconButton(
            tooltip: 'Kişi ekle',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => _add(context),
          ),
        ],
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Kişiler yüklenemedi.',
          onRetry: () => ref.invalidate(ledgersProvider),
        ),
        data: (all) => all.isEmpty
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
            : _PeopleBody(all: all, table: table),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final id = await showAddPersonSheet(context);
    if (id != null && context.mounted) openLedger(context, id);
  }
}

class _PeopleBody extends ConsumerWidget {
  const _PeopleBody({required this.all, required this.table});

  final List<PersonRow> all;
  final bool table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pacta;
    final filter = ref.watch(peopleFilterProvider);
    final rows = selectRows(
      all,
      filter: filter,
      sort: ref.watch(peopleSortProvider),
      query: ref.watch(peopleQueryProvider),
    );
    final totals = SummaryTotals.of(rows);

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: [
        if (all.length >= PeoplePage.searchThreshold)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Kişi ara',
                isDense: true,
              ),
              onChanged: (q) => ref.read(peopleQueryProvider.notifier).state = q,
            ),
          ),
        // Sarılır, kaydırılmaz: tüm seçenekler görünür kalsın.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
          child: Wrap(
            spacing: 8,
            children: [
              for (final f in PeopleFilter.values)
                if (f == PeopleFilter.all ||
                    f == filter ||
                    all.any((r) => r.matches(f)))
                  ChoiceChip(
                    label: Text(
                      '${f.label} (${all.where((r) => r.matches(f)).length})',
                    ),
                    selected: f == filter,
                    showCheckmark: false,
                    onSelected: (_) =>
                        ref.read(peopleFilterProvider.notifier).state = f,
                  ),
            ],
          ),
        ),
        _TotalsCard(totals: totals),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('Bu süzgece uyan kişi yok.', style: TextStyle(color: c.muted)),
                TextButton(
                  onPressed: () {
                    ref.read(peopleFilterProvider.notifier).state =
                        PeopleFilter.all;
                  },
                  child: const Text('Süzgeci temizle'),
                ),
              ],
            ),
          )
        else if (table)
          _SummaryTable(rows: rows, totals: totals)
        else
          SurfaceCard(
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  LedgerTile(
                    ledger: rows[i].ledger,
                    showDivider: i < rows.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Görünen kişilerin TL toplamı: alacak, borç, net.
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals});

  final SummaryTotals totals;

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    Widget cell(String label, Widget value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 2),
          value,
        ],
      ),
    );
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          cell('Alacağınız', AmountText(totals.receivable, color: c.credit)),
          cell('Borcunuz', AmountText(totals.payable, color: c.debt)),
          cell('Net', AmountText(totals.net, signed: true, colorBySign: true)),
        ],
      ),
    );
  }
}

/// Kişi | Bakiye | Bekleyen | Vade; en altta toplam satırı.
class _SummaryTable extends StatelessWidget {
  const _SummaryTable({required this.rows, required this.totals});

  final List<PersonRow> rows;
  final SummaryTotals totals;

  static const _flex = [5, 4, 2, 3];

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final small = TextStyle(fontSize: 12, color: c.muted, fontWeight: FontWeight.w600);

    Widget line(List<Widget> cells, {Color? background, VoidCallback? onTap, bool divider = true}) {
      return InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
          ),
          child: Row(
            children: [
              for (var i = 0; i < cells.length; i++)
                Expanded(flex: _flex[i], child: cells[i]),
            ],
          ),
        ),
      );
    }

    return SurfaceCard(
      child: Column(
        children: [
          line(background: c.line.withValues(alpha: 0.5), [
            Text('Kişi', style: small),
            Text('Bakiye', style: small, textAlign: TextAlign.end),
            Text('Bekl.', style: small, textAlign: TextAlign.center),
            Text('Vade', style: small, textAlign: TextAlign.end),
          ]),
          for (final r in rows)
            line(onTap: () => openLedger(context, r.ledger.id), [
              Text(
                r.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: AmountText(r.balance, signed: true, colorBySign: true),
                  ),
                  for (final m in r.others)
                    Text(
                      m.format(signed: true),
                      style: TextStyle(fontSize: 11, color: c.muted),
                    ),
                ],
              ),
              Center(
                child: r.pendingCount > 0
                    ? StatusChip(label: '${r.pendingCount}', tone: ChipTone.pending)
                    : Text('—', style: TextStyle(color: c.muted)),
              ),
              Text(
                r.nextDue?.dueOn.formatCompact() ?? '—',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 13,
                  color: r.hasOverdue
                      ? c.debt
                      : (r.nextDue == null ? c.muted : null),
                  fontWeight: r.hasOverdue ? FontWeight.w600 : null,
                ),
              ),
            ]),
          line(divider: false, background: c.line.withValues(alpha: 0.5), [
            Text('Toplam', style: const TextStyle(fontWeight: FontWeight.w600)),
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AmountText(totals.net, signed: true, colorBySign: true),
              ),
            ),
            Center(
              child: Text(
                totals.pendingCount > 0 ? '${totals.pendingCount}' : '—',
                style: TextStyle(color: c.muted),
              ),
            ),
            Text(
              '${rows.where((r) => r.hasOverdue).length} gecikmiş',
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12, color: c.muted),
            ),
          ]),
        ],
      ),
    );
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
