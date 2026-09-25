import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../core/ui/widgets.dart';
import '../application/providers.dart';
import '../domain/models.dart';
import 'common.dart';
import 'entry_composer_page.dart';

/// Tek bir kişiyle olan defter: bakiye, hızlı eylemler, kayıtlar.
class LedgerPage extends ConsumerWidget {
  const LedgerPage({super.key, required this.ledgerId});

  final String ledgerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final ledgerAsync = ref.watch(ledgerProvider(ledgerId));
    final entriesAsync = ref.watch(entriesProvider(ledgerId));
    final c = context.pacta;

    return ledgerAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          message: 'Defter açılamadı.',
          onRetry: () => ref.invalidate(ledgerProvider(ledgerId)),
        ),
      ),
      data: (ledger) {
        if (ledger == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.menu_book_rounded,
              title: 'Defter bulunamadı',
              message: 'Bu defter silinmiş ya da erişiminiz yok.',
            ),
          );
        }
        final other = ledger.other(uid);
        final me = ledger.sideOf(uid) ?? Side.a;
        final balance = ledger.balanceFor(uid);
        final others = ledger.balancesFor(uid).where((m) => m.asset != balance.asset);

        final String sentence;
        if (balance.isZero) {
          sentence = 'Hesabınız denk.';
        } else if (balance.isNegative) {
          sentence = '${(-balance).format()} borcunuz var.';
        } else {
          sentence = '${other.displayName} size ${balance.format()} borçlu.';
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                PersonAvatar(
                  name: other.displayName,
                  size: 36,
                  tone: balance.isNegative ? ChipTone.debt : ChipTone.credit,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(other.displayName, overflow: TextOverflow.ellipsis),
                      if (ledger.isPrivate)
                        Text(
                          'Özel defter · yalnızca siz görürsünüz',
                          style: TextStyle(fontSize: 12, color: c.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              SurfaceCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ledger.isPrivate ? 'Bakiye' : 'Onaylı bakiye',
                      style: TextStyle(fontSize: 13, color: c.muted),
                    ),
                    const SizedBox(height: 4),
                    AmountText(
                      balance,
                      signed: true,
                      colorBySign: true,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(sentence),
                    for (final m in others)
                      Text(
                        m.isNegative
                            ? '${(-m).format()} borcunuz var.'
                            : '${m.format()} alacağınız var.',
                        style: TextStyle(color: c.muted),
                      ),
                    if (ledger.pendingCount > 0) ...[
                      const SizedBox(height: 8),
                      StatusChip(
                        label: '${ledger.pendingCount} kayıt onay bekliyor',
                        tone: ChipTone.pending,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _Action(
                          icon: Icons.add_rounded,
                          label: 'Kayıt ekle',
                          onTap: () => _compose(context, ledger),
                        ),
                        const SizedBox(width: 8),
                        _Action(
                          icon: Icons.south_west_rounded,
                          label: balance.isNegative ? 'Ödeme yaptım' : 'Ödeme aldım',
                          onTap: () => _compose(
                            context,
                            ledger,
                            mode: balance.isNegative
                                ? ComposerMode.paid
                                : ComposerMode.received,
                          ),
                        ),
                        if (!ledger.isPrivate && balance.minor > 0) ...[
                          const SizedBox(width: 8),
                          _Action(
                            icon: Icons.send_rounded,
                            label: 'Hatırlat',
                            onTap: () => SharePlus.instance.share(
                              ShareParams(
                                text:
                                    'Merhaba ${other.displayName}, Pacta\'daki '
                                    'ortak hesabımıza göre ${balance.format()} '
                                    'borcun görünüyor. Uygun olduğunda '
                                    'ödeyebilir misin?',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              ...entriesAsync.when(
                loading: () => [
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (e, _) => [
                  ErrorState(
                    message: 'Kayıtlar yüklenemedi.',
                    onRetry: () => ref.invalidate(entriesProvider(ledgerId)),
                  ),
                ],
                data: (entries) => entries.isEmpty
                    ? [
                        EmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: 'Henüz kayıt yok',
                          message: ledger.isPrivate
                              ? 'Eklediğiniz kayıtlar yalnızca sizde tutulur.'
                              : 'İlk kaydı ekleyin; ${other.displayName} '
                                    'onaylayınca bakiyeye işlenir.',
                        ),
                      ]
                    : _grouped(entries, me, ledger.isPrivate),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _grouped(List<LedgerEntry> entries, Side me, bool isPrivate) {
    final groups = <String, List<LedgerEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(e.occurredOn.formatMonth(), () => []).add(e);
    }
    return [
      for (final group in groups.entries) ...[
        SectionHeader(title: group.key),
        SurfaceCard(
          child: Column(
            children: [
              for (var i = 0; i < group.value.length; i++)
                EntryTile(
                  entry: group.value[i],
                  me: me,
                  isPrivate: isPrivate,
                  showDivider: i < group.value.length - 1,
                ),
            ],
          ),
        ),
      ],
    ];
  }

  void _compose(BuildContext context, Ledger ledger, {ComposerMode? mode}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EntryComposerPage(ledgerId: ledger.id, initialMode: mode),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    return Expanded(
      child: Material(
        color: c.creditSoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: c.credit, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
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
  }
}
