import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/dates/local_date.dart';
import '../../../core/money/asset.dart';
import '../../../core/money/money.dart';
import '../../../core/ui/widgets.dart';
import '../application/providers.dart';
import '../domain/models.dart';
import 'common.dart';
import 'people_page.dart';

/// Kaydı girenin bakış açısından dört tür.
enum ComposerMode { lent, borrowed, paid, received }

enum _Due { none, week, month, custom }

/// Yeni kayıt: tür → kişi → tutar → gönder. Tarih bugün, birim TL.
class EntryComposerPage extends ConsumerStatefulWidget {
  const EntryComposerPage({super.key, this.ledgerId, this.initialMode});

  final String? ledgerId;
  final ComposerMode? initialMode;

  @override
  ConsumerState<EntryComposerPage> createState() => _EntryComposerPageState();
}

class _EntryComposerPageState extends ConsumerState<EntryComposerPage> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  late ComposerMode _mode = widget.initialMode ?? ComposerMode.lent;
  late String? _ledgerId = widget.ledgerId;
  late final String _entryId = ref.read(ledgerRepositoryProvider).newId();
  Asset _asset = Asset.tryLira;
  _Due _due = _Due.none;
  LocalDate? _customDue;
  String? _amountError;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _isPayment =>
      _mode == ComposerMode.paid || _mode == ComposerMode.received;

  /// Değer benden çıktı mı: borç verdim, ödeme yaptım.
  bool get _iGave => _mode == ComposerMode.lent || _mode == ComposerMode.paid;

  /// Kaydı girenin aleyhine olan kayıt onay beklemeden işlenir.
  bool get _againstMe => !_iGave;

  LocalDate? get _dueOn {
    final today = LocalDate.today();
    return switch (_due) {
      _Due.none => null,
      _Due.week => today.addDays(7),
      _Due.month => today.addMonths(1),
      _Due.custom => _customDue,
    };
  }

  Money? get _money {
    try {
      final m = Money.parse(_amount.text, _asset);
      return m.minor > 0 ? m : null;
    } on FormatException {
      return null;
    }
  }

  String _preview(String me, Money amount) {
    final a = amount.format();
    final sentence = switch (_mode) {
      ComposerMode.lent => '$me size $a borç yazdı.',
      ComposerMode.borrowed => '$me, sizden $a borç aldığını kaydetti.',
      ComposerMode.paid => '$me size $a ödeme yaptığını bildirdi.',
      ComposerMode.received => '$me, sizden $a ödeme aldığını kaydetti.',
    };
    final due = _dueOn;
    return due == null ? sentence : '$sentence Vadesi ${due.formatShort()}.';
  }

  Future<void> _pickPerson() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PersonPickerSheet(),
    );
    if (id != null) setState(() => _ledgerId = id);
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('tr', 'TR'),
      initialDate: today.add(const Duration(days: 14)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _due = _Due.custom;
        _customDue = LocalDate.fromDateTime(picked);
      });
    }
  }

  Future<void> _submit() async {
    final ledgerId = _ledgerId;
    if (ledgerId == null) {
      await _pickPerson();
      return;
    }
    Money amount;
    try {
      amount = Money.parse(_amount.text, _asset);
      if (amount.minor <= 0) throw const FormatException('Tutar girin.');
    } on FormatException catch (e) {
      setState(() => _amountError = e.message.isEmpty ? 'Tutar girin.' : e.message);
      return;
    }
    setState(() {
      _amountError = null;
      _busy = true;
    });
    EntryState? state;
    final ok = await runCommand(context, () async {
      state = await ref.read(ledgerRepositoryProvider).createEntry(
        ledgerId: ledgerId,
        entryId: _entryId,
        kind: _isPayment ? EntryKind.payment : EntryKind.debt,
        iGave: _iGave,
        amount: amount,
        occurredOn: LocalDate.today(),
        dueOn: _isPayment ? null : _dueOn,
        description: _description.text.trim(),
      );
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      showSnack(
        context,
        state == EntryState.pending ? 'Onaya gönderildi.' : 'Kaydedildi.',
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final uid = ref.watch(currentUidProvider);
    final ledger = _ledgerId == null
        ? null
        : ref.watch(ledgerProvider(_ledgerId!)).valueOrNull;
    final other = ledger?.other(uid);
    final isPrivate = ledger?.isPrivate ?? false;
    final money = _money;

    final String buttonLabel;
    if (ledger == null) {
      buttonLabel = 'Kişi seçin';
    } else if (isPrivate || _againstMe) {
      buttonLabel = 'Kaydet';
    } else {
      buttonLabel = 'Onay için gönder';
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Kapat',
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: const Text('Yeni kayıt'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Borç')),
              ButtonSegment(value: true, label: Text('Ödeme')),
            ],
            selected: {_isPayment},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(
              () => _mode = s.first ? ComposerMode.received : ComposerMode.lent,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<ComposerMode>(
            segments: _isPayment
                ? const [
                    ButtonSegment(value: ComposerMode.received, label: Text('Ödeme aldım')),
                    ButtonSegment(value: ComposerMode.paid, label: Text('Ödeme yaptım')),
                  ]
                : const [
                    ButtonSegment(value: ComposerMode.lent, label: Text('Borç verdim')),
                    ButtonSegment(value: ComposerMode.borrowed, label: Text('Borç aldım')),
                  ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: widget.ledgerId == null ? _pickPerson : null,
              leading: other == null
                  ? CircleAvatar(
                      backgroundColor: c.creditSoft,
                      child: Icon(Icons.person_add_alt_1_rounded, color: c.credit),
                    )
                  : PersonAvatar(name: other.displayName, size: 38),
              title: Text(other?.displayName ?? 'Kişi seçin'),
              subtitle: Text(
                isPrivate ? 'Özel defter' : 'Kime',
                style: TextStyle(fontSize: 12, color: c.muted),
              ),
              trailing: widget.ledgerId == null
                  ? Text(
                      other == null ? 'Seç' : 'Değiştir',
                      style: TextStyle(color: c.credit, fontWeight: FontWeight.w600),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _amount,
            autofocus: widget.ledgerId != null,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              hintText: '0,00',
              errorText: _amountError,
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Asset>(
                    value: _asset,
                    items: [
                      for (final a in Asset.values)
                        DropdownMenuItem(value: a, child: Text(a.symbol)),
                    ],
                    onChanged: (a) => setState(() => _asset = a ?? _asset),
                  ),
                ),
              ),
            ),
            onChanged: (_) => setState(() => _amountError = null),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            maxLength: 280,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Ne için?',
              hintText: 'Örn. akşam yemeği',
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (!_isPayment) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ne zamana kadar?',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                if (_dueOn != null)
                  Text(_dueOn!.format(), style: TextStyle(fontSize: 12, color: c.muted)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (due, label) in const [
                  (_Due.none, 'Vade yok'),
                  (_Due.week, '1 hafta'),
                  (_Due.month, '1 ay'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _due == due,
                    onSelected: (_) => setState(() => _due = due),
                  ),
                ChoiceChip(
                  label: const Text('Tarih seç'),
                  selected: _due == _Due.custom,
                  onSelected: (_) => _pickDate(),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (ledger != null && money != null)
            _PreviewCard(
              title: isPrivate
                  ? 'Özel defter'
                  : '${other!.displayName} şunu görecek',
              text: isPrivate
                  ? 'Bu kayıt yalnızca sizde tutulur ve hemen bakiyeye işlenir.'
                  : _preview(ledger.me(uid).displayName, money),
              note: !isPrivate && _againstMe
                  ? 'Bu kayıt sizin aleyhinize olduğu için onay beklemeden '
                        'bakiyeye işlenir; ${other!.displayName} bilgilendirilir.'
                  : null,
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Text(buttonLabel),
              ),
              if (ledger != null && !isPrivate && !_againstMe) ...[
                const SizedBox(height: 8),
                Text(
                  'Onaylanınca ikinizin bakiyesine işlenir. O zamana kadar '
                  'geri çekebilirsiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.title, required this.text, this.note});

  final String title;
  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.creditSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.credit),
          ),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(height: 1.5)),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(note!, style: TextStyle(fontSize: 12, color: c.muted, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

/// Kayıt için kişi seçimi: mevcut defterler ya da yeni kişi.
class _PersonPickerSheet extends ConsumerWidget {
  const _PersonPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final ledgers = ref.watch(ledgersProvider).valueOrNull ?? const <Ledger>[];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_rounded),
              title: const Text('Yeni kişi ekle'),
              onTap: () async {
                final id = await showAddPersonSheet(context);
                if (id != null && context.mounted) Navigator.of(context).pop(id);
              },
            ),
            for (final l in ledgers)
              ListTile(
                leading: PersonAvatar(name: l.other(uid).displayName, size: 36),
                title: Text(l.other(uid).displayName),
                subtitle: l.isPrivate ? const Text('Özel defter') : null,
                onTap: () => Navigator.of(context).pop(l.id),
              ),
          ],
        ),
      ),
    );
  }
}
