import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/money/asset.dart';
import '../../../core/money/money.dart';
import '../../../core/ui/widgets.dart';
import '../../profile/profile_providers.dart';
import '../application/providers.dart';
import 'add_person_sheet.dart';
import 'common.dart';
import 'contacts_ui.dart';
import 'notifications_page.dart';

/// Ana sayfa: onaylı bakiye, onayınızı bekleyenler, yaklaşan vadeler, kişiler.
class HomePage extends ConsumerWidget {
  const HomePage({
    super.key,
    required this.onSeeAllPeople,
    required this.onOpenActivity,
    required this.onAddEntry,
  });

  final VoidCallback onSeeAllPeople;
  final VoidCallback onOpenActivity;
  final VoidCallback onAddEntry;

  /// Ana sayfada gösterilen vade ufku (gün); tamamı Hareketler'de.
  static const dueHorizonDays = 7;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pacta;
    final name = ref.watch(userProfileProvider).valueOrNull?.adSoyad?.trim();
    final firstName = (name == null || name.isEmpty)
        ? null
        : name.split(' ').first;
    final totals = ref.watch(totalsProvider);
    final inbox = ref.watch(inboxProvider).valueOrNull ?? const [];
    final unread = (ref.watch(notificationsProvider).valueOrNull ?? const [])
        .where((n) => !n.isRead)
        .length;
    final ledgers = ref.watch(visibleLedgersProvider);
    final today = ref.watch(todayProvider);
    final schedule = ref.watch(dueScheduleProvider).valueOrNull;
    final soon = [
      ...?schedule?.overdue,
      ...?schedule?.upcoming.where(
        (r) => r.item.dueOn < today.addDays(dueHorizonDays + 1),
      ),
    ];

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
                        Text(
                          'Merhaba,',
                          style: TextStyle(fontSize: 13, color: c.muted),
                        ),
                        Text(
                          firstName ?? 'Hoş geldiniz',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Bildirimler',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationsPage(),
                      ),
                    ),
                    icon: Badge(
                      isLabelVisible: unread > 0,
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
                      child: StatusChip(
                        label: '${inbox.length}',
                        tone: ChipTone.pending,
                      ),
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
                    onPressed: onOpenActivity,
                    child: Text('Tümünü gör (${inbox.length})'),
                  ),
                ),
            ],
            if (soon.isNotEmpty) ...[
              SectionHeader(
                title: 'Yaklaşan vadeler',
                trailing: TextButton(
                  onPressed: onOpenActivity,
                  child: const Text('Tümü'),
                ),
              ),
              SurfaceCard(
                child: Column(
                  children: [
                    for (var i = 0; i < soon.length && i < 3; i++)
                      DueTile(
                        row: soon[i],
                        today: today,
                        showDivider: i < soon.length - 1 && i < 2,
                      ),
                  ],
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
                  ? [GettingStarted(onAddEntry: onAddEntry)]
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

/// Henüz kimse eklenmemişken: Pacta'nın nasıl çalıştığı ve üç adım.
class GettingStarted extends StatelessWidget {
  const GettingStarted({super.key, required this.onAddEntry});

  final VoidCallback onAddEntry;

  Future<void> _addPerson(BuildContext context) async {
    final id = await showAddPersonSheet(context);
    if (id != null && context.mounted) openLedger(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final text = Theme.of(context).textTheme;

    Widget step(
      int number,
      String title,
      String body,
      String action,
      VoidCallback onTap,
    ) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.creditSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(fontWeight: FontWeight.w700, color: c.credit),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: c.muted, height: 1.4)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: onTap,
                    child: Text(action),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return SurfaceCard(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Icon(Icons.handshake_rounded, color: c.credit),
                const SizedBox(width: 10),
                Text(
                  'Başlarken',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Pacta, bir kişiyle aranızdaki borçları birlikte tuttuğunuz '
              'defterdir. Karşı tarafın aleyhine bir kayıt, o onaylamadan '
              'bakiyeye girmez.',
              style: TextStyle(color: c.muted, height: 1.4),
            ),
          ),
          step(
            1,
            'Kişi ekleyin',
            'E-posta, Pacta kodu ya da QR ile bulun. Uygulaması olmayan biri '
                'için yalnızca sizin göreceğiniz özel defter açın.',
            'Kişi ekle',
            () => _addPerson(context),
          ),
          step(
            2,
            'İlk kaydı girin',
            'Borç verdim, borç aldım ya da ödeme. Karşı taraf onaylayınca '
                'bakiyenize işlenir.',
            'Kayıt ekle',
            onAddEntry,
          ),
          step(
            3,
            'Kodunuzu paylaşın',
            'Arkadaşlarınız sizi QR ya da davet linkiyle hemen eklesin.',
            'Pacta kodum',
            () => openPactaCodePage(context),
          ),
        ],
      ),
    );
  }
}
