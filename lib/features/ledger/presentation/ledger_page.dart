import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/money/asset.dart';
import '../../../core/report.dart';
import '../../../core/ui/widgets.dart';
import '../../profile/profile_providers.dart';
import '../application/providers.dart';
import '../data/ledger_repository.dart';
import '../domain/models.dart';
import '../domain/reminder.dart';
import '../domain/summary.dart';
import 'common.dart';
import 'contacts_ui.dart';
import 'convert_ledger_page.dart';
import 'entry_composer_page.dart';
import 'statement_export.dart';

/// Tek bir kişiyle olan defter: bakiye, hızlı eylemler, kayıtlar.
/// Defter sayfasında ilk çizilen kayıt sayısı; "daha eski" ile artar.
const ledgerPageSize = 100;

final _visibleEntriesProvider = StateProvider.autoDispose.family<int, String>(
  (ref, ledgerId) => ledgerPageSize,
);

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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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
        final all = ledger.balancesFor(uid);
        final balance = ledger.primaryBalance(uid);
        final others = all.where((m) => m.asset != balance.asset);
        final today = ref.watch(todayProvider);
        final plan = ReminderPlan.of(
          ledger,
          entriesAsync.valueOrNull ?? const [],
          uid,
          today,
        );
        final muted =
            ref
                .watch(userProfileProvider)
                .valueOrNull
                ?.reminderMutes
                .contains(ledger.id) ??
            false;
        final favorite = ref.watch(favoriteLedgersProvider).contains(ledger.id);
        final archived = ref.watch(archivedLedgersProvider(ledger.id));

        final String sentence;
        if (ledger.isArchived) {
          // Bakiye ortak deftere taşındı; burada kalan eski hâlidir.
          sentence = 'Bu bakiye ortak deftere taşındı.';
        } else if (balance.isZero) {
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
                      if (ledger.isArchived)
                        Text(
                          'Arşiv · ortak deftere taşındı',
                          style: TextStyle(fontSize: 12, color: c.muted),
                        )
                      else if (ledger.isPrivate)
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
              // Arşivdeki defter listelerde görünmez; favori anlamsız.
              if (!ledger.isArchived)
                IconButton(
                  tooltip: favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
                  icon: Icon(
                    favorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: favorite ? c.pendingDot : null,
                  ),
                  onPressed: () => ref
                      .read(ledgerRepositoryProvider)
                      .setFavorite(uid, ledger.id, !favorite)
                      .catchError((Object e, StackTrace st) {
                        reportError(e, st, reason: 'Favori kaydedilemedi');
                        if (context.mounted) {
                          showSnack(
                            context,
                            'Favori kaydedilemedi. Tekrar deneyin.',
                            error: true,
                          );
                        }
                      }),
                ),
              PopupMenuButton<String>(
                tooltip: 'Diğer',
                onSelected: (value) {
                  // Bu sayfanın rotası baştan alınır: işlem sürerken üstte
                  // başka bir sayfa açılırsa o kapanmaz, bu sayfa kaldırılır.
                  final route = ModalRoute.of(context);
                  void close() {
                    if (!context.mounted || route == null || !route.isActive) {
                      return;
                    }
                    final navigator = Navigator.of(context);
                    if (route.isCurrent) {
                      navigator.pop();
                    } else {
                      navigator.removeRoute(route);
                    }
                  }

                  switch (value) {
                    case 'mute':
                      _toggleMute(context, ref, ledger, muted);
                    case 'block':
                      _toggleBlock(context, ref, ledger);
                    case 'convert':
                      _convert(context, ledger);
                    case 'pdf':
                      exportStatement(context, ref, ledger, ExportFormat.pdf);
                    case 'csv':
                      exportStatement(context, ref, ledger, ExportFormat.csv);
                    case 'person' when ledger.isPrivate:
                      deletePrivateLedger(
                        context,
                        ref,
                        ledger,
                        onDeleted: close,
                      );
                    case 'person':
                      hidePerson(context, ref, ledger, onHidden: close);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'pdf',
                    child: Text('Ekstre (PDF)'),
                  ),
                  const PopupMenuItem(value: 'csv', child: Text('Tablo (CSV)')),
                  if (ledger.isPrivate && !ledger.isClosed)
                    const PopupMenuItem(
                      value: 'convert',
                      child: Text('Ortak deftere taşı'),
                    ),
                  if (!ledger.isPrivate && !ledger.isClosed)
                    PopupMenuItem(
                      value: 'block',
                      child: Text(
                        ledger.blockedByMe(uid) ? 'Engeli kaldır' : 'Engelle',
                      ),
                    ),
                  if (!ledger.isPrivate && !ledger.isClosed)
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
                      ledger.isPrivate ? 'Defteri sil' : 'Listeden kaldır',
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
                      ledger.isArchived
                          ? 'Taşınmadan önceki bakiye'
                          : (ledger.isPrivate ? 'Bakiye' : 'Onaylı bakiye'),
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
                    // Taşınan özel defter ve karşı tarafı hesabını silen
                    // defter yalnızca okunur.
                    if (ledger.isArchived)
                      _ClosedNote(
                        text:
                            'Bu defter ${other.displayName} ile ortak deftere '
                            'taşındı. Eski kayıtlarınız burada, yalnızca '
                            'sizde duruyor.',
                        action: 'Ortak defteri aç',
                        onAction: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                LedgerPage(ledgerId: ledger.convertedTo!),
                          ),
                        ),
                      )
                    else if (ledger.isClosed)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.line,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Bu kişi Pacta hesabını sildi. Ortak geçmişiniz '
                          'burada saklanıyor; yeni kayıt eklenemez.',
                          style: TextStyle(color: c.muted),
                        ),
                      )
                    else if (ledger.blocksMe(uid))
                      _ClosedNote(
                        text:
                            '${other.displayName} kişisine şu an kayıt, '
                            'düzeltme ya da hatırlatma gönderilemiyor. '
                            'Bekleyen kayıtlarınızı geri çekebilirsiniz.',
                      )
                    else ...[
                      if (ledger.blockedByMe(uid)) ...[
                        _ClosedNote(
                          text:
                              '${other.displayName} kişisini engellediniz. '
                              'Size kayıt, düzeltme ya da hatırlatma '
                              'gönderemez; siz kayıt eklemeye devam '
                              'edebilirsiniz.',
                          action: 'Engeli kaldır',
                          onAction: () => _toggleBlock(context, ref, ledger),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          _Action(
                            icon: Icons.add_rounded,
                            label: 'Kayıt ekle',
                            onTap: () => _compose(context, ledger),
                          ),
                          // Bakiye denkse ödeme kısayolu yok (kim kime?);
                          // birim bakiyeninkidir (altın borcu altınla).
                          if (!balance.isZero) ...[
                            const SizedBox(width: 8),
                            _Action(
                              icon: Icons.south_west_rounded,
                              label: balance.isNegative
                                  ? 'Ödeme yaptım'
                                  : 'Ödeme aldım',
                              onTap: () => _compose(
                                context,
                                ledger,
                                mode: balance.isNegative
                                    ? ComposerMode.paid
                                    : ComposerMode.received,
                                asset: balance.asset,
                              ),
                            ),
                          ],
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
                  ],
                ),
              ),
              if (ledger.isPrivate && !ledger.isClosed)
                SurfaceCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.group_add_outlined, color: c.credit),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${other.displayName} Pacta\'ya katıldı mı? Ortak '
                          'deftere taşıyın; kayıtları o da onaylasın.',
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _convert(context, ledger),
                        child: const Text('Taşı'),
                      ),
                    ],
                  ),
                ),
              for (final old in archived)
                SurfaceCard(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('Özel defterdeki eski kayıtlar'),
                    // Birden çok arşiv varsa hangisi olduğu ad ile ayrılır.
                    subtitle: Text(
                      '${old.b.displayName} · yalnızca siz görürsünüz',
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: c.muted),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LedgerPage(ledgerId: old.id),
                      ),
                    ),
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
                    : _grouped(context, ref, entries, me, ledger.isPrivate),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Kayıtlar işlem tarihine göre (yeniden eskiye) aylara ayrılır; aynı
  /// gündekiler giriliş sırasına göre. Sunucu oluşturulma sırasıyla
  /// gönderir; tarihi değiştirilen kayıt yanlış ayın altında kalmasın.
  List<Widget> _grouped(
    BuildContext context,
    WidgetRef ref,
    List<LedgerEntry> entries,
    Side me,
    bool isPrivate,
  ) {
    final sorted = [...entries]..sort(newestFirst);
    final limit = ref.watch(_visibleEntriesProvider(ledgerId));
    final shown = sorted.take(limit);
    final groups = <String, List<LedgerEntry>>{};
    for (final e in shown) {
      groups.putIfAbsent(e.occurredOn.formatMonth(), () => []).add(e);
    }
    final hidden = sorted.length - limit;
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
      if (hidden > 0)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
            child: TextButton(
              onPressed: () =>
                  ref.read(_visibleEntriesProvider(ledgerId).notifier).state +=
                      ledgerPageSize,
              child: Text('Daha eski kayıtlar ($hidden)'),
            ),
          ),
        ),
    ];
  }

  /// İşlem tarihi yeniden eskiye; aynı gün içinde son girilen önce.
  static int newestFirst(LedgerEntry x, LedgerEntry y) {
    final c = y.occurredOn.compareTo(x.occurredOn);
    if (c != 0) return c;
    final tx = x.createdAt;
    final ty = y.createdAt;
    if (tx != null && ty != null && tx != ty) return ty.compareTo(tx);
    return y.id.compareTo(x.id);
  }

  /// Taşıma başarılıysa bu sayfa ortak defterle değişir.
  Future<void> _convert(BuildContext context, Ledger ledger) async {
    final result = await openConvertLedgerPage(context, ledger);
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LedgerPage(ledgerId: result.ledgerId),
      ),
    );
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.pending > 0
              ? 'Ortak deftere taşındı. ${result.pending} kayıt onay bekliyor.'
              : 'Ortak deftere taşındı.',
        ),
      ),
    );
  }

  void _compose(
    BuildContext context,
    Ledger ledger, {
    ComposerMode? mode,
    Asset? asset,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EntryComposerPage(
          ledgerId: ledger.id,
          initialMode: mode,
          initialAsset: asset,
        ),
      ),
    );
  }

  Future<void> _toggleBlock(
    BuildContext context,
    WidgetRef ref,
    Ledger ledger,
  ) async {
    final uid = ref.read(currentUidProvider);
    final name = ledger.other(uid).displayName;
    final block = !ledger.blockedByMe(uid);
    if (block) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$name engellensin mi?'),
          content: Text(
            '$name size yeni kayıt, düzeltme ya da hatırlatma gönderemez. '
            'Bekleyen kayıtlarını geri çekebilir, sizin kayıtlarınızı '
            'yanıtlayabilir. Ortak geçmişiniz silinmez; engeli istediğiniz '
            'zaman kaldırabilirsiniz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Engelle'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    await runCommand(
      context,
      () => ref.read(ledgerRepositoryProvider).setBlocked(ledger.id, block),
      success: block ? '$name engellendi.' : 'Engel kaldırıldı.',
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
      // Pencere bu arada kapandıysa arkadaki sayfa kapatılmaz.
      if (mounted) navigator.pop();
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
    } catch (e, stack) {
      // Beklenmeyen yanıt: panel "meşgul"de kilitli kalmasın.
      reportError(e, stack, reason: 'Hatırlatma yanıtı okunamadı');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Hatırlatma gönderilemedi. Tekrar deneyin.';
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
          Expanded(
            child: Text(value, style: TextStyle(color: c.muted)),
          ),
        ],
      ),
    );

    // Gönderim sürerken pencere kapatılamaz.
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
      ),
    );
  }
}

class _ClosedNote extends StatelessWidget {
  const _ClosedNote({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, 12, 12, action == null ? 12 : 4),
      decoration: BoxDecoration(
        color: c.line,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: TextStyle(color: c.muted)),
          if (action != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onAction, child: Text(action!)),
            ),
        ],
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: c.credit, size: 20),
                  const SizedBox(height: 4),
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
      ),
    );
  }
}
