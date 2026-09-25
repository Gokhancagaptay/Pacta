import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/money/asset.dart';
import '../../../core/money/money.dart';
import '../../../core/ui/widgets.dart';
import '../../profile/profile_providers.dart';
import '../application/providers.dart';
import 'common.dart';

/// Ana sayfa: onaylı bakiye, onayınızı bekleyenler, kişiler.
class HomePage extends ConsumerWidget {
  const HomePage({
    super.key,
    required this.onSeeAllPeople,
    required this.onOpenInbox,
    required this.onAddEntry,
  });

  final VoidCallback onSeeAllPeople;
  final VoidCallback onOpenInbox;
  final VoidCallback onAddEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pacta;
    final name = ref.watch(userProfileProvider).valueOrNull?.adSoyad?.trim();
    final firstName = (name == null || name.isEmpty) ? null : name.split(' ').first;
    final totals = ref.watch(totalsProvider);
    final inbox = ref.watch(inboxProvider).valueOrNull ?? const [];
    final ledgers = ref.watch(ledgersProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ledgersProvider);
          ref.invalidate(inboxProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Merhaba,', style: TextStyle(fontSize: 13, color: c.muted)),
                        Text(
                          firstName ?? 'Hoş geldiniz',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gelen kutusu',
                    onPressed: onOpenInbox,
                    icon: Badge(
                      isLabelVisible: inbox.isNotEmpty,
                      backgroundColor: c.pendingDot,
                      smallSize: 9,
                      child: const Icon(Icons.notifications_none_rounded),
                    ),
                  ),
                ],
              ),
            ),
            totals.when(
              loading: () => const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => BalanceCard(
                net: const Money(0, Asset.tryLira),
                receivable: const Money(0, Asset.tryLira),
                payable: const Money(0, Asset.tryLira),
                footnote: 'Bakiye şu an yüklenemedi.',
              ),
              data: (t) => BalanceCard(
                net: t.net,
                receivable: t.receivable,
                payable: t.payable,
                footnote: t.othersSentence,
              ),
            ),
            SectionHeader(
              title: 'Onayınızı bekleyen',
              trailing: inbox.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: StatusChip(label: '${inbox.length}', tone: ChipTone.pending),
                    ),
            ),
            if (inbox.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Onayınızı bekleyen kayıt yok.',
                  style: TextStyle(color: c.muted),
                ),
              )
            else ...[
              for (final item in inbox.take(3)) ...[
                InboxCard(item: item),
                const SizedBox(height: 10),
              ],
              if (inbox.length > 3)
                Center(
                  child: TextButton(
                    onPressed: onOpenInbox,
                    child: Text('Tümünü gör (${inbox.length})'),
                  ),
                ),
            ],
            ...ledgers.when(
              loading: () => const <Widget>[],
              error: (e, _) => [
                ErrorState(
                  message: 'Kişiler yüklenemedi.',
                  onRetry: () => ref.invalidate(ledgersProvider),
                ),
              ],
              data: (list) => list.isEmpty
                  ? [
                      EmptyState(
                        icon: Icons.handshake_rounded,
                        title: 'İlk kaydınızı ekleyin',
                        message:
                            'Kime borç verdiğinizi ya da kimden aldığınızı '
                            'yazın. Karşı taraf onaylayınca bakiyeniz burada '
                            'görünür.',
                        action: FilledButton(
                          onPressed: onAddEntry,
                          child: const Text('Kayıt ekle'),
                        ),
                      ),
                    ]
                  : [
                      SectionHeader(
                        title: 'Kişiler',
                        trailing: TextButton(
                          onPressed: onSeeAllPeople,
                          child: Text('Tümü (${list.length})'),
                        ),
                      ),
                      SurfaceCard(
                        child: Column(
                          children: [
                            for (var i = 0; i < list.length && i < 4; i++)
                              LedgerTile(
                                ledger: list[i],
                                showDivider: i < list.length - 1 && i < 3,
                              ),
                          ],
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
