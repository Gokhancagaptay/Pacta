import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../profile/profile_providers.dart';
import '../application/providers.dart';
import '../data/ledger_repository.dart';
import '../domain/models.dart';
import '../domain/reminder.dart';
import '../domain/summary.dart';
import 'common.dart';
import 'contacts_ui.dart';
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
        final today = ref.watch(todayProvider);
        final plan = ReminderPlan.of(
          ledger,
          entriesAsync.valueOrNull ?? const [],
          uid,
          today,
        );
        final muted =
            ref.watch(userProfileProvider).valueOrNull?.reminderMutes.contains(
              ledger.id,
            ) ??
            false;
        final favorite = ref.watch(favoriteLedgersProvider).contains(ledger.id);

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
                        )
                      else if (other.email != null)
                        Text(
                          other.email!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
                icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: favorite ? c.pendingDot : null,
                ),
                onPressed: () => ref
                    .read(ledgerRepositoryProvider)
                    .setFavorite(uid, ledger.id, !favorite),
              ),
              PopupMenuButton<String>(
                tooltip: 'Diğer',
                onSelected: (value) {
                  void close() => Navigator.of(context).maybePop();
                  switch (value) {
                    case 'mute':
                      _toggleMute(context, ref, ledger, muted);
                    case 'person' when ledger.isPrivate:
                      deletePrivateLedger(context, ref, ledger, onDeleted: close);
                    case 'person':
                      hidePerson(context, ref, ledger, onHidden: close);
                  }
                },
                itemBuilder: (_) => [
                  if (!ledger.isPrivate)
                    PopupMenuItem(
                      value: 'mute',
                      child: Text(
                        muted
                            ? 'Hatırlatmaları aç'
                            : 'Hatırlatmaları sessize al',
                      ),
                    ),
                  PopupMenuItem(
                    value: 'person',
                    child: Text(
                      ledger.isPrivate
                          ? 'Defteri sil'
                          : 'Listeden kaldır',
                    ),
                  ),
                ],
              ),
            ],
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
                        if (plan.isRelevant) ...[
                          const SizedBox(width: 8),
                          _Action(
                            icon: Icons.notifications_active_outlined,
                            label: 'Hatırlat',
                            onTap: () => showReminderSheet(
                              context,
                              ledger: ledger,
                              plan: plan,
                              fromName: ledger.me(uid).displayName,
                            ),
                          ),
                        ] else if (ledger.isPrivate) ...[
                          // Karşı taraf uygulamada değil: hatırlatma yerine davet.
                          const SizedBox(width: 8),
                          _Action(
                            icon: Icons.share_rounded,
                            label: 'Davet et',
                            onTap: () => shareInvite(context, ref),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (ledger.dueItems.isNotEmpty) ...[
                const SectionHeader(title: 'Vadeler'),
                SurfaceCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < ledger.dueItems.length; i++)
                        DueTile(
                          row: DueRow(
                            ledger: ledger,
                            item: ledger.dueItems[i],
                            name: other.displayName,
                            amount: ledger.dueItems[i].signedFor(me),
                          ),
                          today: today,
                          showName: false,
                          showDivider: i < ledger.dueItems.length - 1,
                        ),
                    ],
                  ),
                ),
              ],
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

  Future<void> _toggleMute(
    BuildContext context,
    WidgetRef ref,
    Ledger ledger,
    bool muted,
  ) async {
    final uid = ref.read(currentUidProvider);
    try {
      await ref
          .read(ledgerRepositoryProvider)
          .setReminderMuted(uid, ledger.id, !muted);
      if (context.mounted) {
        showSnack(
          context,
          muted
              ? 'Hatırlatmalar yeniden açıldı.'
              : '${ledger.other(uid).displayName} kişisinin hatırlatmaları '
                    'artık bildirim olarak gelmeyecek.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'Ayar kaydedilemedi. Tekrar deneyin.', error: true);
      }
    }
  }
}

/// Hatırlatma önizlemesi ve gönderme. Karşı tarafın göreceği metin aynen
/// gösterilir; tutar yazılmaz, sıklık sınırı baştan söylenir.
Future<void> showReminderSheet(
  BuildContext context, {
  required Ledger ledger,
  required ReminderPlan plan,
  required String fromName,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) =>
      _ReminderSheet(ledger: ledger, plan: plan, fromName: fromName),
);

class _ReminderSheet extends ConsumerStatefulWidget {
  const _ReminderSheet({
    required this.ledger,
    required this.plan,
    required this.fromName,
  });

  final Ledger ledger;
  final ReminderPlan plan;
  final String fromName;

  @override
  ConsumerState<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<_ReminderSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final result = await ref
          .read(ledgerRepositoryProvider)
          .sendReminder(widget.ledger.id);
      navigator.pop();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.queued
                ? 'Hatırlatma iletildi. Gece olduğu için bildirim sabah '
                      '09:00\'da gidecek.'
                : 'Hatırlatma gönderildi.',
          ),
        ),
      );
    } on LedgerException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final text = Theme.of(context).textTheme;
    final plan = widget.plan;
    final kind = plan.kind!;
    final preview = ReminderPlan.text(kind, widget.fromName, plan.waiting);
    final uid = ref.watch(currentUidProvider);
    final otherName = widget.ledger.other(uid).displayName;
    final interval = ReminderPlan.intervalDays(kind);

    Widget note(IconData icon, String value) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(value, style: TextStyle(color: c.muted))),
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nazik bir hatırlatma',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '$otherName uygulamada şu bildirimi görecek:',
              style: TextStyle(color: c.muted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.line.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notifications_rounded, color: c.credit),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preview.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(preview.message),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            note(Icons.lock_outline_rounded, 'Tutar bildirimde görünmez.'),
            note(
              Icons.schedule_rounded,
              'Aynı kişiye $interval günde bir hatırlatma gönderebilirsiniz.',
            ),
            note(
              Icons.bedtime_outlined,
              '21:00–09:00 arasında gönderilirse bildirim sabah gider.',
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (plan.nextOn != null)
              StatusChip(
                label:
                    'Yakın zamanda hatırlattınız. Bir sonraki: '
                    '${plan.nextOn!.formatShort()}',
                tone: ChipTone.pending,
                icon: Icons.schedule_rounded,
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _busy ? null : _send,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Hatırlatma gönder'),
              ),
          ],
        ),
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
