import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/money/asset.dart';
import '../../../core/money/money.dart';
import '../../../core/ui/widgets.dart';
import '../application/providers.dart';
import '../data/ledger_repository.dart';
import '../domain/models.dart';
import 'common.dart';

// Gelen kutusunda toplu onay. Yanlışlıkla toplu borç onaylanmasın diye
// başlangıçta hiçbir kayıt seçili değildir; seçilenlerin bakiyeye etkisi
// birim birim gösterilir. Her kayıt ayrı komutla, görülen sürümüyle
// onaylanır: arada değişen kayıt onaylanmaz, işaretli kalır.

/// Toplu onaya girebilecek kayıtlar (itiraz sonrası düzenleme bekleyenler
/// hariç). En az iki kayıt varsa toplu onay önerilir.
List<InboxItem> bulkConfirmable(List<InboxItem> inbox) => [
  for (final item in inbox)
    if (item.needsConfirmation) item,
];

/// Seçilen kayıtların bakiyenize etkisi, birim başına (sıfır olanlar yok).
/// Birimler karışmaz.
List<Money> bulkConfirmEffect(Iterable<InboxItem> items) {
  final sums = <Asset, int>{};
  for (final item in items) {
    sums[item.amount.asset] =
        (sums[item.amount.asset] ?? 0) + item.myDeltaMinor;
  }
  return [
    for (final asset in Asset.values)
      if ((sums[asset] ?? 0) != 0) Money(sums[asset]!, asset),
  ];
}

String _keyOf(InboxItem item) => '${item.ledgerId}/${item.entryId}';

Future<void> showBulkConfirmSheet(
  BuildContext context,
  List<InboxItem> items,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => BulkConfirmSheet(items: items),
);

class BulkConfirmSheet extends ConsumerStatefulWidget {
  const BulkConfirmSheet({super.key, required this.items});

  final List<InboxItem> items;

  @override
  ConsumerState<BulkConfirmSheet> createState() => _BulkConfirmSheetState();
}

class _BulkConfirmSheetState extends ConsumerState<BulkConfirmSheet> {
  final _selected = <String>{};

  /// Onaylanamayan kayıtlar ve nedeni.
  final _failed = <String, String>{};
  bool _busy = false;
  int _done = 0;
  int _total = 0;

  List<InboxItem> get _chosen => [
    for (final item in widget.items)
      if (_selected.contains(_keyOf(item))) item,
  ];

  Future<void> _confirm() async {
    final chosen = _chosen;
    if (chosen.isEmpty) return;
    final repo = ref.read(ledgerRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _done = 0;
      _total = chosen.length;
      _failed.clear();
    });
    var confirmed = 0;
    for (final item in chosen) {
      try {
        await repo.confirmById(item.ledgerId, item.entryId, item.version);
        confirmed++;
        if (mounted) setState(() => _selected.remove(_keyOf(item)));
      } on LedgerException catch (e) {
        _failed[_keyOf(item)] = e.isStale
            ? 'Kayıt değişti; açıp yeni hâlini inceleyin.'
            : e.message;
      } catch (_) {
        _failed[_keyOf(item)] = 'Onaylanamadı. Tekrar deneyin.';
      }
      if (mounted) setState(() => _done++);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (_failed.isEmpty) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('$confirmed kayıt onaylandı. Bakiyenize işlendi.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final theme = Theme.of(context);
    final chosen = _chosen;
    final allSelected = chosen.length == widget.items.length;
    final effect = bulkConfirmEffect(chosen);

    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Toplu onay', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Onaylamak istediğiniz kayıtları tek tek seçin. Onaylanan '
              'kayıtlar bakiyenize işlenir; geri almak için düzeltme gerekir.',
              style: TextStyle(fontSize: 13, color: c.muted),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: allSelected,
              onChanged: _busy
                  ? null
                  : (on) => setState(() {
                      _selected.clear();
                      if (on == true) {
                        _selected.addAll(widget.items.map(_keyOf));
                      }
                    }),
              title: Text('Tümünü seç (${widget.items.length})'),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in widget.items)
                    _ItemRow(
                      item: item,
                      selected: _selected.contains(_keyOf(item)),
                      error: _failed[_keyOf(item)],
                      onChanged: _busy
                          ? null
                          : (on) => setState(() {
                              if (on == true) {
                                _selected.add(_keyOf(item));
                              } else {
                                _selected.remove(_keyOf(item));
                              }
                            }),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (chosen.isNotEmpty)
              Semantics(
                container: true,
                child: Text(
                  'Bakiyenize etkisi: '
                  '${effect.isEmpty ? '0' : effect.map((m) => m.format(signed: true)).join(', ')}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_failed.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${_failed.length} kayıt onaylanamadı; işaretli kaldı.',
                style: TextStyle(fontSize: 13, color: c.debt),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || chosen.isEmpty ? null : _confirm,
              child: _busy
                  ? Text('Onaylanıyor: $_done / $_total')
                  : Text(
                      chosen.isEmpty
                          ? 'Kayıt seçin'
                          : '${chosen.length} kaydı onayla',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.selected,
    required this.onChanged,
    this.error,
  });

  final InboxItem item;
  final bool selected;
  final ValueChanged<bool?>? onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final mine = Money(item.myDeltaMinor, item.amount.asset);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: selected,
      onChanged: onChanged,
      title: Text(inboxTitle(item)),
      subtitle: error != null
          ? Text(error!, style: TextStyle(color: c.debt))
          : item.description.isEmpty
          ? null
          : Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      secondary: AmountText(mine, colorBySign: true),
    );
  }
}
