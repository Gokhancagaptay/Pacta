import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/ui/widgets.dart';
import '../application/providers.dart';
import '../domain/summary.dart';
import 'add_person_sheet.dart';
import 'common.dart';
import 'contacts_ui.dart';

export 'add_person_sheet.dart' show showAddPersonSheet;

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
            ? ListView(
                children: [
                  EmptyState(
                    icon: Icons.people_alt_rounded,
                    title: 'Henüz kimse yok',
                    message:
                        'Borç ya da alacak takip ettiğiniz kişileri ekleyin. '
                        'QR okutarak, Pacta koduyla ya da e-postayla '
                        'ekleyebilirsiniz.',
                    action: FilledButton(
                      onPressed: () => _add(context),
                      child: const Text('Kişi ekle'),
                    ),
                  ),
                  const _HiddenLink(),
                ],
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
    final searchable = all.length >= PeoplePage.searchThreshold;
    final rows = selectRows(
      all,
      filter: filter,
      sort: ref.watch(peopleSortProvider),
      // Arama kutusu görünmüyorsa eski sorgu listeyi süzmez.
      query: searchable ? ref.watch(peopleQueryProvider) : '',
    );
    final totals = SummaryTotals.of(rows);

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: [
        if (searchable) const _SearchField(),
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
                    ref.read(peopleQueryProvider.notifier).state = '';
                  },
                  child: const Text('Süzgeci ve aramayı temizle'),
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
        if (rows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(
              'İpucu: Bir kişiye basılı tutarak favorilere ekleyebilir ya da '
              'listeden kaldırabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.muted),
            ),
          ),
        const _HiddenLink(),
      ],
    );
  }
}

/// Kişi araması; sorgu dışarıdan temizlenince kutu da boşalır.
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final _controller = TextEditingController(
    text: ref.read(peopleQueryProvider),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(peopleQueryProvider, (_, next) {
      if (next != _controller.text) _controller.text = next;
    });
    final hasText = ref.watch(peopleQueryProvider).isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: 'Ad ya da e-posta ara',
          isDense: true,
          suffixIcon: !hasText
              ? null
              : IconButton(
                  tooltip: 'Aramayı temizle',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () =>
                      ref.read(peopleQueryProvider.notifier).state = '',
                ),
        ),
        onChanged: (q) => ref.read(peopleQueryProvider.notifier).state = q,
      ),
    );
  }
}

/// "Listeden kaldırılanlar (2)": varsa gösterilir, geri getirmeyi açar.
class _HiddenLink extends ConsumerWidget {
  const _HiddenLink();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(hiddenLedgersProvider).length;
    if (count == 0) return const SizedBox.shrink();
    return Center(
      child: TextButton.icon(
        onPressed: () => showHiddenPeopleSheet(context),
        icon: const Icon(Icons.visibility_off_outlined, size: 18),
        label: Text('Listeden kaldırılanlar ($count)'),
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              cell('Alacağınız', AmountText(totals.receivable, color: c.credit)),
              cell('Borcunuz', AmountText(totals.payable, color: c.debt)),
              cell('Net', AmountText(totals.net, signed: true, colorBySign: true)),
            ],
          ),
          const SizedBox(height: 6),
          // Ana sayfadaki toplam kaldırılan kişileri de içerir; bu yalnızca
          // listede görünenlerin TL toplamıdır.
          Text(
            'Listede görünen kişilerin TL toplamı',
            style: TextStyle(fontSize: 11, color: c.muted),
          ),
        ],
      ),
    );
  }
}

/// Kişi | Bakiye | Bekleyen | Vade; en altta toplam satırı.
class _SummaryTable extends ConsumerWidget {
  const _SummaryTable({required this.rows, required this.totals});

  final List<PersonRow> rows;
  final SummaryTotals totals;

  static const _flex = [5, 4, 2, 3];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pacta;
    final small = TextStyle(fontSize: 12, color: c.muted, fontWeight: FontWeight.w600);

    Widget line(
      List<Widget> cells, {
      Color? background,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
      bool divider = true,
    }) {
      return InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
            line(
              onTap: () => openLedger(context, r.ledger.id),
              onLongPress: () => showPersonActions(context, ref, r.ledger),
              [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (r.favorite) ...[
                        Icon(Icons.star_rounded, size: 14, color: c.pendingDot),
                        const SizedBox(width: 2),
                      ],
                      Flexible(
                        child: Text(
                          r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  if (r.email != null)
                    Text(
                      r.email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: c.muted),
                    ),
                ],
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

