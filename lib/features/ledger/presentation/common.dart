import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/dates/local_date.dart';
import '../../../core/money/money.dart';
import '../../../core/ui/widgets.dart';
import '../../../services/notification_routes.dart';
import '../application/providers.dart';
import '../data/ledger_repository.dart';
import '../domain/entry_text.dart';
import '../domain/models.dart';
import '../domain/summary.dart';
import 'contacts_ui.dart';
import 'entry_detail_page.dart';
import 'ledger_page.dart';

void showSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ),
  );
}

/// Komutu çalıştırır; hata olursa kullanıcıya Türkçe anlatır.
Future<bool> runCommand(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (success != null && context.mounted) showSnack(context, success);
    return true;
  } on LedgerException catch (e) {
    if (context.mounted) {
      showSnack(
        context,
        e.isStale ? 'Kayıt değişti; güncel hâli gösteriliyor.' : e.message,
        error: !e.isStale,
      );
    }
    return false;
  }
}

void openLedger(BuildContext context, String ledgerId) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => LedgerPage(ledgerId: ledgerId)));

void openEntry(BuildContext context, String ledgerId, String entryId) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EntryDetailPage(ledgerId: ledgerId, entryId: entryId),
      ),
    );

/// Bildirim rotasını açar: `/l/<defter>` ya da `/l/<defter>/e/<kayıt>`.
void openRoute(BuildContext context, String route) {
  final target = NotificationRoutes.parse(route);
  if (target == null) return;
  if (target.entryId != null) {
    openEntry(context, target.ledgerId, target.entryId!);
  } else {
    openLedger(context, target.ledgerId);
  }
}

/// Kişi listesi satırı: ad, durum (bekleyen / vade) ve onaylı TL bakiyesi.
class LedgerTile extends ConsumerWidget {
  const LedgerTile({super.key, required this.ledger, this.showDivider = true});

  final Ledger ledger;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final today = ref.watch(todayProvider);
    final other = ledger.other(uid);
    final balance = ledger.balanceFor(uid);
    final c = context.pacta;
    final due = ledger.dueItems.isEmpty ? null : ledger.dueItems.first.dueOn;
    String? subtitle;
    var subtitleColor = c.muted;
    if (ledger.pendingCount > 0) {
      subtitle = '${ledger.pendingCount} kayıt onay bekliyor';
      subtitleColor = c.pending;
    } else if (due != null && due < today) {
      subtitle = 'Vadesi geçti · ${due.formatShort()}';
      subtitleColor = c.debt;
    } else if (due != null) {
      subtitle = 'Vade: ${due.formatShort()}';
    } else if (ledger.isPrivate) {
      subtitle = 'Özel defter';
    }
    final favorite = ref.watch(favoriteLedgersProvider).contains(ledger.id);

    return InkWell(
      onTap: () => openLedger(context, ledger.id),
      onLongPress: () => showPersonActions(context, ref, ledger),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: showDivider ? Border(bottom: BorderSide(color: c.line)) : null,
        ),
        child: Row(
          children: [
            PersonAvatar(
              name: other.displayName,
              size: 38,
              tone: balance.isNegative ? ChipTone.debt : ChipTone.credit,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          other.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (favorite) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: c.pendingDot,
                          semanticLabel: 'Favori',
                        ),
                      ],
                    ],
                  ),
                  if (other.email != null)
                    Text(
                      other.email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.muted),
                    ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                ],
              ),
            ),
            AmountText(balance, signed: true, colorBySign: true),
          ],
        ),
      ),
    );
  }
}

/// Defterdeki kayıt satırı.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.me,
    this.isPrivate = false,
    this.showDivider = true,
  });

  final LedgerEntry entry;
  final Side me;
  final bool isPrivate;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final status = EntryText.status(entry, me, isPrivate: isPrivate);
    final counted = entry.state == EntryState.confirmed;
    final mine = Money(entry.deltaFor(me), entry.asset);
    final (fg, bg) = (counted ? status.tone : ChipTone.neutral) == ChipTone.neutral
        ? (c.muted, c.line)
        : status.tone.colors(c, Theme.of(context).colorScheme);
    final title = entry.description.isEmpty
        ? EntryText.title(entry, me)
        : '${EntryText.title(entry, me)} · ${entry.description}';

    return InkWell(
      onTap: () => openEntry(context, entry.ledgerId, entry.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: showDivider ? Border(bottom: BorderSide(color: c.line)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: entry.isOpen ? c.pendingSoft : bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                entry.isOpen ? Icons.schedule_rounded : status.icon,
                size: 18,
                color: entry.isOpen ? c.pending : fg,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${entry.occurredOn.formatShort()} · ${status.label}',
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
              mine,
              signed: true,
              colorBySign: counted && entry.reversedBy == null,
              color: counted && entry.reversedBy == null ? null : c.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Açık vade satırı: tarih rozeti, kişi, ne kadar kaldığı, kalan tutar.
class DueTile extends StatelessWidget {
  const DueTile({
    super.key,
    required this.row,
    required this.today,
    this.showName = true,
    this.showDivider = true,
  });

  final DueRow row;
  final LocalDate today;
  final bool showName;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final item = row.item;
    final overdue = item.dueOn < today;
    final soon = !overdue && item.dueOn < today.addDays(4);
    final (fg, bg) = overdue
        ? (c.debt, c.debtSoft)
        : soon
        ? (c.pending, c.pendingSoft)
        : (c.muted, c.line);
    final what = row.iOwe ? 'Ödeyeceğiniz' : 'Alacağınız';
    final title = showName
        ? row.name
        : (item.description.isEmpty ? what : item.description);
    final details = [
      if (showName) what,
      if (showName && item.description.isNotEmpty) item.description,
      relativeDue(item.dueOn, today),
    ].join(' · ');

    return InkWell(
      onTap: () => openEntry(context, row.ledger.id, item.entryId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: showDivider ? Border(bottom: BorderSide(color: c.line)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${item.dueOn.day}',
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    item.dueOn.formatCompact().split(' ').last,
                    style: TextStyle(color: fg, fontSize: 10, height: 1.1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: overdue ? c.debt : c.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AmountText(row.amount, signed: true, colorBySign: true),
          ],
        ),
      ),
    );
  }
}

/// Gelen kutusu öğesinin tek cümlelik başlığı.
String inboxTitle(InboxItem item) {
  if (!item.needsConfirmation) return '${item.fromName} kaydınıza itiraz etti';
  return switch (item.kind) {
    EntryKind.reversal => '${item.fromName} bir kaydı düzeltmek istiyor',
    EntryKind.debt => item.myDeltaMinor < 0
        ? '${item.fromName} size borç yazdı'
        : '${item.fromName} sizden borç aldığını yazdı',
    EntryKind.payment => item.myDeltaMinor < 0
        ? '${item.fromName} ödeme bildirdi'
        : '${item.fromName} ödeme aldığını bildirdi',
  };
}

/// Onay bekleyen kart; [actions] açıksa satır içi Onayla / İncele.
class InboxCard extends ConsumerStatefulWidget {
  const InboxCard({super.key, required this.item, this.actions = false});

  final InboxItem item;
  final bool actions;

  @override
  ConsumerState<InboxCard> createState() => _InboxCardState();
}

class _InboxCardState extends ConsumerState<InboxCard> {
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final item = widget.item;
    await runCommand(
      context,
      () => ref
          .read(ledgerRepositoryProvider)
          .confirmById(item.ledgerId, item.entryId, item.version),
      success: 'Onaylandı. Bakiyenize işlendi.',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final item = widget.item;
    final mine = Money(item.myDeltaMinor, item.amount.asset);
    final subtitle = [
      if (item.description.isNotEmpty) item.description,
      if (!item.needsConfirmation) 'Düzeltmeniz bekleniyor',
    ].join(' · ');

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          InkWell(
            onTap: () => openEntry(context, item.ledgerId, item.entryId),
            child: Row(
              children: [
                PersonAvatar(
                  name: item.fromName,
                  tone: item.needsConfirmation ? ChipTone.pending : ChipTone.dispute,
                  square: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inboxTitle(item),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.muted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AmountText(mine, colorBySign: true),
              ],
            ),
          ),
          if (widget.actions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (item.needsConfirmation) ...[
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                      onPressed: _busy ? null : _confirm,
                      child: Text(
                        item.kind == EntryKind.payment ? 'Aldım, onayla' : 'Onayla',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: () => openEntry(context, item.ledgerId, item.entryId),
                    child: Text(item.needsConfirmation ? 'İncele' : 'Düzelt'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
