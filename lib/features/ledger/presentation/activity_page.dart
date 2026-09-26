import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/dates/local_date.dart';
import '../../../core/money/asset.dart';
import '../../../core/money/money.dart';
import '../../../core/ui/widgets.dart';
import '../application/providers.dart';
import '../domain/entry_text.dart';
import '../domain/models.dart';
import '../domain/summary.dart';
import 'common.dart';

/// Hareketler: "ne olacak" (onayınızı bekleyenler, vadeler) ve "ne oldu"
/// (tüm defterlerdeki son kayıtlar).
class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hareketler'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Yaklaşan'),
              Tab(text: 'Geçmiş'),
            ],
          ),
        ),
        body: const TabBarView(children: [_UpcomingTab(), _HistoryTab()]),
      ),
    );
  }
}

class _UpcomingTab extends ConsumerWidget {
  const _UpcomingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxProvider).valueOrNull ?? const [];
    final schedule = ref.watch(dueScheduleProvider);
    final today = ref.watch(todayProvider);

    return schedule.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(
        message: 'Vadeler yüklenemedi.',
        onRetry: () => ref.invalidate(ledgersProvider),
      ),
      data: (s) {
        if (inbox.isEmpty && s.isEmpty) {
          return const EmptyState(
            icon: Icons.event_available_rounded,
            title: 'Yaklaşan bir şey yok',
            message:
                'Onayınızı bekleyen kayıtlar ve vadesi yaklaşan ödemeler burada '
                'görünür. Kayıt eklerken bir vade tarihi seçebilirsiniz.',
          );
        }
        Widget dueCard(List<DueRow> rows) => SurfaceCard(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                DueTile(
                  row: rows[i],
                  today: today,
                  showDivider: i < rows.length - 1,
                ),
            ],
          ),
        );
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (s.overdue.isNotEmpty || s.upcoming.isNotEmpty)
              _OutlookCard(schedule: s),
            if (inbox.isNotEmpty) ...[
              SectionHeader(
                title: 'Onayınızı bekleyen',
                trailing: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: StatusChip(
                    label: '${inbox.length}',
                    tone: ChipTone.pending,
                  ),
                ),
              ),
              for (final item in inbox) ...[
                InboxCard(item: item, actions: true),
                const SizedBox(height: 10),
              ],
            ],
            if (s.overdue.isNotEmpty) ...[
              const SectionHeader(title: 'Vadesi geçenler'),
              dueCard(s.overdue),
            ],
            if (s.upcoming.isNotEmpty) ...[
              const SectionHeader(title: 'Önümüzdeki 30 gün'),
              dueCard(s.upcoming),
            ],
            if (s.later.isNotEmpty) ...[
              const SectionHeader(title: 'Daha sonra'),
              dueCard(s.later),
            ],
          ],
        );
      },
    );
  }
}

/// Gecikmiş ve 30 gün içindeki TL toplamları: alacak ve borç ayrı.
class _OutlookCard extends StatelessWidget {
  const _OutlookCard({required this.schedule});

  final DueSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    var incoming = 0;
    var outgoing = 0;
    var overdue = 0;
    for (final r in [...schedule.overdue, ...schedule.upcoming]) {
      if (r.amount.asset != Asset.tryLira) continue;
      if (r.iOwe) {
        outgoing -= r.amount.minor;
      } else {
        incoming += r.amount.minor;
      }
    }
    for (final r in schedule.overdue) {
      if (r.amount.asset == Asset.tryLira) overdue += r.amount.minor.abs();
    }
    Widget box(String label, int minor, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 2),
          AmountText(Money(minor, Asset.tryLira), color: color),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            box('Tahsil edilecek', incoming, c.credit),
            box('Ödenecek', outgoing, c.debt),
            if (overdue > 0) box('Vadesi geçen', overdue, c.debt),
          ],
        ),
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final ledgersAsync = ref.watch(ledgersProvider);
    final ledgers = {
      for (final l in ledgersAsync.valueOrNull ?? const <Ledger>[]) l.id: l,
    };
    final recent = ref.watch(recentEntriesProvider);
    final today = ref.watch(todayProvider);

    // Kişiler yüklenmeden kayıtlar süzülürse "Henüz hareket yok" yanıp söner.
    if (ledgersAsync.isLoading && ledgers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return recent.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(
        message: 'Hareketler yüklenemedi.',
        onRetry: () => ref.invalidate(recentEntriesProvider),
      ),
      data: (entries) {
        final visible = [
          for (final e in entries)
            if (ledgers[e.ledgerId] != null) e,
        ];
        if (visible.isEmpty) {
          return const EmptyState(
            icon: Icons.history_rounded,
            title: 'Henüz hareket yok',
            message:
                'Eklediğiniz, onayladığınız ve düzelttiğiniz kayıtlar burada '
                'tarih sırasıyla görünür.',
          );
        }
        final groups = <String, List<LedgerEntry>>{};
        for (final e in visible) {
          groups.putIfAbsent(_dayLabel(e.updatedAt, today), () => []).add(e);
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            for (final g in groups.entries) ...[
              SectionHeader(title: g.key),
              SurfaceCard(
                child: Column(
                  children: [
                    for (var i = 0; i < g.value.length; i++)
                      _HistoryTile(
                        entry: g.value[i],
                        ledger: ledgers[g.value[i].ledgerId]!,
                        uid: uid,
                        showDivider: i < g.value.length - 1,
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static String _dayLabel(DateTime? at, LocalDate today) {
    if (at == null) return 'Şimdi';
    final day = LocalDate.fromDateTime(at);
    if (day == today) return 'Bugün';
    if (day == today.addDays(-1)) return 'Dün';
    return day.formatShort();
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.ledger,
    required this.uid,
    required this.showDivider,
  });

  final LedgerEntry entry;
  final Ledger ledger;
  final String uid;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final me = ledger.sideOf(uid) ?? Side.a;
    final name = ledger.other(uid).displayName;
    final status = EntryText.status(entry, me, isPrivate: ledger.isPrivate);
    final counted =
        entry.state == EntryState.confirmed &&
        entry.reversedBy == null &&
        entry.kind != EntryKind.reversal;
    final title = entry.description.isEmpty
        ? EntryText.title(entry, me)
        : '${EntryText.title(entry, me)} · ${entry.description}';
    final time = entry.updatedAt == null
        ? null
        : DateFormat('HH:mm', 'tr_TR').format(entry.updatedAt!);

    return InkWell(
      onTap: () => openEntry(context, entry.ledgerId, entry.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: showDivider ? Border(bottom: BorderSide(color: c.line)) : null,
        ),
        child: Row(
          children: [
            PersonAvatar(
              name: name,
              size: 36,
              tone: entry.isOpen ? ChipTone.pending : status.tone,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.muted),
                  ),
                  Text(
                    [status.label, ?time].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: entry.isOpen ? c.pending : c.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AmountText(
              Money(entry.deltaFor(me), entry.asset),
              signed: true,
              colorBySign: counted,
              color: counted ? null : c.muted,
            ),
          ],
        ),
      ),
    );
  }
}
