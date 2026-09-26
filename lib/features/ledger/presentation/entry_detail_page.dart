import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/dates/local_date.dart';
import '../../../core/money/money.dart';
import '../../../core/ui/widgets.dart';
import '../application/providers.dart';
import '../data/ledger_repository.dart';
import '../domain/entry_text.dart';
import '../domain/models.dart';
import 'common.dart';

/// Tek kaydın ayrıntısı ve kullanıcının yapabileceği eylemler.
class EntryDetailPage extends ConsumerStatefulWidget {
  const EntryDetailPage({super.key, required this.ledgerId, required this.entryId});

  final String ledgerId;
  final String entryId;

  @override
  ConsumerState<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends ConsumerState<EntryDetailPage> {
  bool _busy = false;

  EntryKey get _key => (ledgerId: widget.ledgerId, entryId: widget.entryId);
  LedgerRepository get _repo => ref.read(ledgerRepositoryProvider);

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    await runCommand(context, action, success: success);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final entryAsync = ref.watch(entryProvider(_key));
    final ledgerAsync = ref.watch(ledgerProvider(widget.ledgerId));
    final ledger = ledgerAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt detayı')),
      body: entryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Kayıt açılamadı.',
          onRetry: () => ref.invalidate(entryProvider(_key)),
        ),
        data: (entry) {
          // Defter henüz yüklenirken "kayıt yok" denmez.
          if (ledgerAsync.isLoading && ledger == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (entry == null || ledger == null) {
            return const EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'Bu kayıt artık yok',
              message: 'Kayıt silinmiş ya da erişiminiz kalmamış olabilir.',
            );
          }
          final me = ledger.sideOf(uid) ?? Side.a;
          return _Body(
            entry: entry,
            ledger: ledger,
            me: me,
            events: ref.watch(entryEventsProvider(_key)).valueOrNull ?? const [],
          );
        },
      ),
      bottomNavigationBar: entryAsync.valueOrNull == null || ledger == null
          ? null
          : _actions(entryAsync.value!, ledger, ledger.sideOf(uid) ?? Side.a),
    );
  }

  Widget? _actions(LedgerEntry e, Ledger ledger, Side me) {
    final c = context.pacta;
    final other = ledger.other(ref.read(currentUidProvider)).displayName;
    final List<Widget> children;
    String? hint;

    if (e.state == EntryState.pending && e.awaitingSide == me) {
      // Düzeltme kaydının tutarı değiştirilemez; itiraz yerine reddedilir.
      final isReversal = e.kind == EntryKind.reversal;
      hint = isReversal
          ? 'Onaylarsanız iki kayıt birbirini sıfırlar. Katılmıyorsanız '
              'reddedin.'
          : 'Onaylarsanız ikinizin bakiyesine işlenir. Yanlışsa itiraz edin, '
              '$other düzeltsin.';
      children = [
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() => _repo.confirm(e), 'Onaylandı. Bakiyenize işlendi.'),
          icon: const Icon(Icons.check_rounded),
          label: Text(e.kind == EntryKind.payment ? 'Aldım, onayla' : 'Onayla'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (!isReversal) ...[
              Expanded(
                child: _SoftButton(
                  label: 'İtiraz et',
                  fg: c.dispute,
                  bg: c.disputeSoft,
                  onPressed: _busy ? null : () => _dispute(e),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _SoftButton(
                label: 'Reddet',
                fg: c.debt,
                bg: c.debtSoft,
                onPressed: _busy ? null : () => _reject(e),
              ),
            ),
          ],
        ),
      ];
    } else if (e.isOpen && e.proposedBy == me) {
      hint = e.kind == EntryKind.reversal
          ? '$other onaylayana kadar geri çekebilirsiniz.'
          : e.state == EntryState.disputed
          ? 'Tutarı, tarihi ya da açıklamayı düzeltin; $other yeniden '
                'onaylayabilir.'
          : '$other onaylayana kadar düzeltebilir ya da geri çekebilirsiniz.';
      children = [
        Row(
          children: [
            if (e.kind != EntryKind.reversal) ...[
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _revise(e),
                  child: const Text('Düzelt'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                onPressed: _busy ? null : () => _cancel(e),
                child: const Text('Geri çek'),
              ),
            ),
          ],
        ),
      ];
    } else if (e.canBeReversed) {
      children = [
        OutlinedButton(
          onPressed: _busy ? null : () => _reverse(e, ledger, me),
          child: const Text('Bu kaydı düzelt'),
        ),
      ];
      hint = ledger.isPrivate
          ? null
          : 'Onaylı kayıt değiştirilemez; düzeltme için ters kayıt açılır.';
    } else {
      return null;
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hint != null) ...[
              Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: c.muted),
              ),
              const SizedBox(height: 10),
            ],
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _dispute(LedgerEntry e) async {
    final result = await showModalBottomSheet<(String, String, Money?)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DisputeSheet(entry: e),
    );
    if (result == null) return;
    await _run(
      () => _repo.dispute(e, reason: result.$1, note: result.$2, suggested: result.$3),
      'İtirazınız iletildi.',
    );
  }

  Future<void> _reject(LedgerEntry e) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _ChoiceSheet(
        title: 'Neden reddediyorsunuz?',
        subtitle: 'Reddedilen kayıt bakiyeye hiç işlenmez ve kapanır.',
        options: EntryText.rejectReasons,
        confirmLabel: 'Reddet',
      ),
    );
    if (reason == null) return;
    await _run(() => _repo.reject(e, reason: reason), 'Kayıt reddedildi.');
  }

  Future<void> _revise(LedgerEntry e) async {
    final result = await showModalBottomSheet<_Revision>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReviseSheet(entry: e),
    );
    if (result == null) return;
    await _run(
      () => _repo.revise(
        e,
        amount: result.amount,
        description: result.description,
        occurredOn: result.occurredOn,
        dueOn: result.dueOn,
        clearDue: result.dueOn == null && e.dueOn != null,
      ),
      'Düzeltildi ve yeniden onaya gönderildi.',
    );
  }

  Future<void> _cancel(LedgerEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydı geri çek?'),
        content: const Text(
          'Kayıt kapanır ve bakiyeye işlenmez. Karşı tarafın onay isteği '
          'de kalkar.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Geri çek')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => _repo.cancel(e), 'Kayıt geri çekildi.');
  }

  Future<void> _reverse(LedgerEntry e, Ledger ledger, Side me) async {
    final other = ledger.other(ref.read(currentUidProvider)).displayName;
    // Lehinize bir kaydı düzeltmek sizin aleyhinizedir: onay beklemeden işlenir.
    final immediate = !ledger.isPrivate && e.deltaFor(me) > 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydı düzelt?'),
        content: Text(
          ledger.isPrivate
              ? 'Kaydın tersi eklenir ve bakiye eski hâline döner.'
              : immediate
              ? 'Kaydın tersi hemen işlenir ve bakiye bu kayıttan önceki '
                    'hâline döner; onay beklenmez. $other bilgilendirilir, '
                    'geçmiş korunur.'
              : 'Kaydın tersi olan bir düzeltme kaydı açılır. $other '
                    'onaylayınca iki kayıt birbirini sıfırlar; geçmiş korunur.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Düzelt')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => _repo.reverse(e),
      immediate || ledger.isPrivate
          ? 'Kayıt düzeltildi.'
          : 'Düzeltme kaydı açıldı; $other onaylayınca işlenecek.',
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.entry,
    required this.ledger,
    required this.me,
    required this.events,
  });

  final LedgerEntry entry;
  final Ledger ledger;
  final Side me;
  final List<LedgerEvent> events;

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final uid = me == Side.a ? ledger.a.uid : ledger.b.uid;
    final otherName = ledger.other(uid ?? '').displayName;
    final status = EntryText.status(entry, me, isPrivate: ledger.isPrivate);
    final mine = entry.deltaFor(me);
    final dispute = entry.dispute;
    final time = DateFormat('d MMM HH:mm', 'tr_TR');

    Widget row(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: c.muted)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: FontWeight.w500, color: color),
            ),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              StatusChip(label: status.label, tone: status.tone, icon: status.icon),
              const SizedBox(height: 10),
              AmountText(
                entry.amount,
                color: mine < 0 ? c.debt : c.credit,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                EntryText.sentence(entry, me, otherName),
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            children: [
              if (entry.description.isNotEmpty) row('Açıklama', entry.description),
              row('İşlem tarihi', entry.occurredOn.format()),
              if (entry.dueOn != null) row('Vade', entry.dueOn!.format()),
              if (entry.version > 1)
                row('Durum', '${entry.version - 1} kez düzeltildi', color: c.dispute),
            ],
          ),
        ),
        // Düzeltme ile düzeltilen kayıt ve borca bağlı ödeme birbirine gider.
        for (final (label, id) in [
          if (entry.kind == EntryKind.reversal && entry.linkedEntryId != null)
            ('Düzeltilen kayda git', entry.linkedEntryId!),
          if (entry.kind == EntryKind.payment && entry.linkedEntryId != null)
            ('Ödenen borca git', entry.linkedEntryId!),
          if (entry.reversedBy != null) ('Düzeltme kaydına git', entry.reversedBy!),
          if (entry.reversalPendingId != null)
            ('Bekleyen düzeltmeye git', entry.reversalPendingId!),
        ])
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton.icon(
                onPressed: () => openEntry(context, entry.ledgerId, id),
                icon: const Icon(Icons.link_rounded, size: 18),
                label: Text(label),
              ),
            ),
          ),
        if (dispute != null && entry.state == EntryState.disputed) ...[
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.disputeSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İtiraz: ${EntryText.disputeReasons[dispute.reason] ?? 'Diğer'}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: c.dispute),
                ),
                if (dispute.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('“${dispute.note}”'),
                ],
                if (dispute.suggestedAmountMinor != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Önerilen tutar: '
                    '${Money(dispute.suggestedAmountMinor!, entry.asset).format()}',
                  ),
                ],
              ],
            ),
          ),
        ],
        if (events.isNotEmpty) ...[
          const SectionHeader(title: 'Kaydın geçmişi'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (final ev in events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(
                            color: ev.type == 'disputed'
                                ? c.dispute
                                : (ev.type == 'confirmed' ? c.credit : c.pendingDot),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${EntryText.eventLabel(ev.type)} · '
                                '${ev.actorUid == uid ? 'siz' : otherName}'
                                '${ev.version > 1 ? ' (${ev.version}. sürüm)' : ''}',
                              ),
                              if (ev.at != null)
                                Text(
                                  time.format(ev.at!),
                                  style: TextStyle(fontSize: 12, color: c.muted),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({
    required this.label,
    required this.fg,
    required this.bg,
    required this.onPressed,
  });

  final String label;
  final Color fg;
  final Color bg;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      minimumSize: const Size.fromHeight(48),
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}

/// Seçenekli onay sayfası (ret gerekçesi vb.); seçilen anahtarı döner.
class _ChoiceSheet extends StatefulWidget {
  const _ChoiceSheet({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.confirmLabel,
  });

  final String title;
  final String subtitle;
  final Map<String, String> options;
  final String confirmLabel;

  @override
  State<_ChoiceSheet> createState() => _ChoiceSheetState();
}

class _ChoiceSheetState extends State<_ChoiceSheet> {
  late String _selected = widget.options.keys.first;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(widget.subtitle, style: TextStyle(color: context.pacta.muted)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v ?? _selected),
              child: Column(
                children: [
                  for (final o in widget.options.entries)
                    RadioListTile<String>(
                      value: o.key,
                      title: Text(o.value),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context, _selected),
              child: Text(widget.confirmLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisputeSheet extends StatefulWidget {
  const _DisputeSheet({required this.entry});

  final LedgerEntry entry;

  @override
  State<_DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends State<_DisputeSheet> {
  String _reason = 'amount';
  final _note = TextEditingController();
  final _amount = TextEditingController();
  String? _amountError;

  @override
  void dispose() {
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    Money? suggested;
    if (_reason == 'amount' && _amount.text.trim().isNotEmpty) {
      try {
        suggested = Money.parse(_amount.text, widget.entry.asset);
      } on FormatException catch (e) {
        setState(() => _amountError = e.message);
        return;
      }
    }
    Navigator.pop(context, (_reason, _note.text.trim(), suggested));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('İtiraz et', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Kayıt, düzeltilmesi için karşı tarafa döner. Bakiyeye işlenmez.',
              style: TextStyle(color: context.pacta.muted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in EntryText.disputeReasons.entries)
                  ChoiceChip(
                    label: Text(o.value),
                    selected: _reason == o.key,
                    onSelected: (_) => setState(() => _reason = o.key),
                  ),
              ],
            ),
            if (_reason == 'amount') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Doğru tutar (isteğe bağlı)',
                  suffixText: widget.entry.asset.symbol,
                  errorText: _amountError,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 280,
              decoration: const InputDecoration(
                labelText: 'Not (isteğe bağlı)',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _submit, child: const Text('İtirazı gönder')),
          ],
        ),
      ),
    );
  }
}

/// Düzeltme sonucu: değişen alanlar yeni sürüm olarak onaya gider.
typedef _Revision = ({
  Money amount,
  String description,
  LocalDate occurredOn,
  LocalDate? dueOn,
});

class _ReviseSheet extends StatefulWidget {
  const _ReviseSheet({required this.entry});

  final LedgerEntry entry;

  @override
  State<_ReviseSheet> createState() => _ReviseSheetState();
}

class _ReviseSheetState extends State<_ReviseSheet> {
  LedgerEntry get _e => widget.entry;

  /// İtirazda önerilen tutar varsa başlangıç değeri odur (kullanıcıya
  /// söylenir); yoksa mevcut tutar.
  late final int? _suggested = _e.dispute?.suggestedAmountMinor;
  late final _amount = TextEditingController(
    text: Money(_suggested ?? _e.amountMinor, _e.asset).format(withSymbol: false),
  );
  late final _description = TextEditingController(text: _e.description);
  late LocalDate _occurredOn = _e.occurredOn;
  late LocalDate? _dueOn = _e.dueOn;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<LocalDate?> _pick(LocalDate initial, {LocalDate? first}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.toDateTime(),
      firstDate: (first ?? LocalDate(initial.year - 20, 1, 1)).toDateTime(),
      lastDate: DateTime(initial.year + 30, 12, 31),
      locale: const Locale('tr', 'TR'),
    );
    return picked == null ? null : LocalDate.fromDateTime(picked);
  }

  void _submit() {
    final Money amount;
    try {
      amount = Money.parse(_amount.text, _e.asset);
      if (amount.minor <= 0) throw const FormatException('Tutar girin.');
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    final due = _dueOn;
    if (due != null && due < _occurredOn) {
      setState(() => _error = 'Vade, işlem tarihinden önce olamaz.');
      return;
    }
    final description = _description.text.trim();
    final unchanged =
        amount.minor == _e.amountMinor &&
        description == _e.description &&
        _occurredOn == _e.occurredOn &&
        due == _e.dueOn;
    if (unchanged) {
      setState(() => _error = 'Hiçbir şeyi değiştirmediniz.');
      return;
    }
    Navigator.pop<_Revision>(context, (
      amount: amount,
      description: description,
      occurredOn: _occurredOn,
      dueOn: due,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final isDebt = _e.kind == EntryKind.debt;
    final due = _dueOn;

    Widget dateRow(String label, String value, VoidCallback onTap, {Widget? trailing}) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: TextStyle(color: c.muted, fontSize: 13)),
          subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          trailing: trailing ?? const Icon(Icons.edit_calendar_outlined),
          onTap: onTap,
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Kaydı düzelt', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Düzeltilen kayıt yeniden onaya gider.',
              style: TextStyle(color: c.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Tutar',
                suffixText: _e.asset.symbol,
                helperText: _suggested == null
                    ? null
                    : 'Karşı tarafın önerdiği tutar yazıldı; isterseniz değiştirin.',
                helperMaxLines: 2,
              ),
            ),
            dateRow('İşlem tarihi', _occurredOn.format(), () async {
              final picked = await _pick(_occurredOn);
              if (picked != null) setState(() => _occurredOn = picked);
            }),
            if (isDebt)
              dateRow(
                'Vade',
                due == null ? 'Vade yok' : due.format(),
                () async {
                  final picked = await _pick(due ?? _occurredOn, first: _occurredOn);
                  if (picked != null) setState(() => _dueOn = picked);
                },
                trailing: due == null
                    ? const Icon(Icons.edit_calendar_outlined)
                    : IconButton(
                        tooltip: 'Vadeyi kaldır',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _dueOn = null),
                      ),
              ),
            TextField(
              controller: _description,
              maxLength: 280,
              decoration: const InputDecoration(labelText: 'Açıklama', counterText: ''),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            FilledButton(onPressed: _submit, child: const Text('Düzelt ve gönder')),
          ],
        ),
      ),
    );
  }
}
