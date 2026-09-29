import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/ui/widgets.dart';
import '../application/providers.dart';
import '../data/ledger_repository.dart';
import '../domain/models.dart';
import '../domain/pacta_code.dart';
import '../domain/transfer_plan.dart';
import 'contacts_ui.dart';

/// Özel defteri ortak deftere taşır; başarılıysa ortak defterin sonucunu
/// döner (çağıran sayfa ortak deftere geçer).
Future<ConvertResult?> openConvertLedgerPage(
  BuildContext context,
  Ledger ledger,
) => Navigator.of(context).push<ConvertResult>(
  MaterialPageRoute(builder: (_) => ConvertLedgerPage(ledger: ledger)),
);

/// Kişi Pacta'ya katıldıysa: onu e-posta, Pacta kodu ya da QR ile bulun;
/// açık bakiye (vadeleriyle) onun onayına gider. Gönderilecekler önceden
/// aynen gösterilir; özel notlar istenmedikçe gitmez.
class ConvertLedgerPage extends ConsumerStatefulWidget {
  const ConvertLedgerPage({super.key, required this.ledger});

  final Ledger ledger;

  @override
  ConsumerState<ConvertLedgerPage> createState() => _ConvertLedgerPageState();
}

class _ConvertLedgerPageState extends ConsumerState<ConvertLedgerPage> {
  final _query = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _withDescriptions = false;

  /// Kodla bulunan kişi; taşımadan önce adı gösterilir.
  /// Bulunan kişi: yazılan kod ya da e-posta (küçük harf) ve adı. Taşıma
  /// geri alınamaz; önce ad gösterilir, ikinci dokunuşta taşınır.
  ({String key, String name})? _found;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  LedgerRepository get _repo => ref.read(ledgerRepositoryProvider);

  void _fail(String message) => setState(() {
    _busy = false;
    _error = message;
  });

  Future<void> _lookup({String? code, String? email}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = email != null
          ? await _repo.previewEmail(email)
          : await _repo.previewCode(code!);
      if (!mounted) return;
      if (preview.self) {
        _fail(
          email != null
              ? 'Bu sizin e-postanız. Kişinin e-postasını girin.'
              : 'Bu sizin kodunuz. Kişinin Pacta kodunu girin.',
        );
        return;
      }
      setState(() {
        _busy = false;
        _found = (key: email?.toLowerCase() ?? code!, name: preview.name);
      });
    } on LedgerException catch (e) {
      if (mounted) _fail(e.message);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScanCodePage()));
    if (code == null || !mounted) return;
    _query.text = formatPactaCode(code);
    await _lookup(code: code);
  }

  Future<void> _submit() async {
    final text = _query.text.trim();
    if (text.isEmpty) {
      _fail('Kişinin e-posta adresini ya da Pacta kodunu girin.');
      return;
    }
    String? email;
    String? code;
    if (text.contains('@')) {
      email = text;
      // E-postada da önce kişinin adı gösterilir; taşıma ikinci dokunuşta.
      if (_found?.key != email.toLowerCase()) {
        await _lookup(email: email);
        return;
      }
    } else {
      code = parsePactaCode(text);
      if (code == null) {
        _fail(
          'Bu bir e-posta ya da Pacta kodu değil. Kod 6 karakterdir '
          '(ör. K7Q-3XM).',
        );
        return;
      }
      // Kodla önce kişinin adı gösterilir; taşıma ikinci dokunuşta.
      if (_found?.key != code) {
        await _lookup(code: code);
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      final result = await _repo.convertPrivateLedger(
        widget.ledger.id,
        email: email,
        code: code,
        includeDescriptions: _withDescriptions,
      );
      if (mounted) navigator.pop(result);
    } on LedgerException catch (e) {
      if (mounted) _fail(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final uid = ref.watch(currentUidProvider);
    final name = widget.ledger.other(uid).displayName;
    final lines = transferPlan(
      widget.ledger,
      withDescriptions: _withDescriptions,
    );
    final hasNotes = widget.ledger.dueItems.any(
      (i) => i.description.isNotEmpty,
    );
    final approval = lines.any((l) => l.needsApproval);
    final mine = lines.any((l) => !l.needsApproval);
    final found = _found;

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

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Ortak deftere taşı')),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                '$name Pacta\'ya katıldıysa bu defteri onunla ortak deftere '
                'taşıyın. Kayıtlar onun onayına gider; ikiniz de aynı '
                'bakiyeyi görürsünüz.',
                style: TextStyle(color: c.muted, height: 1.4),
              ),
            ),
            const SectionHeader(title: 'Kişiyi bulun'),
            SurfaceCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _query,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'E-posta ya da Pacta kodu',
                      hintText: 'ornek@mail.com ya da K7Q-3XM',
                      errorText: _error,
                      errorMaxLines: 4,
                      suffixIcon: IconButton(
                        tooltip: 'QR okut',
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        onPressed: _busy ? null : _scan,
                      ),
                    ),
                    // Düğme metni ("Kişiyi bul" / "Ortak deftere taşı")
                    // yazılana göre değişir.
                    onChanged: (_) => setState(() {
                      _found = null;
                      _error = null;
                    }),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (found != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        PersonAvatar(name: found.name, size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            found.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Icon(Icons.check_circle_rounded, color: c.credit),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SectionHeader(title: 'Gönderilecekler'),
            SurfaceCard(
              child: lines.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Açık bakiye yok. Kişi ortak defterle eklenir; bu '
                        'defter arşive alınır.',
                        style: TextStyle(color: c.muted),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < lines.length; i++) ...[
                          ListTile(
                            title: Text(lines[i].description),
                            subtitle: Text(
                              lines[i].dueOn == null
                                  ? 'Vadesiz'
                                  : 'Vade: ${lines[i].dueOn!.formatShort()}',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                AmountText(
                                  lines[i].amount,
                                  signed: true,
                                  colorBySign: true,
                                ),
                                Text(
                                  lines[i].needsApproval
                                      ? 'Onayına gider'
                                      : 'Hemen işlenir',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: c.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (i < lines.length - 1)
                            const Divider(height: 1, indent: 16),
                        ],
                      ],
                    ),
            ),
            if (hasNotes)
              SurfaceCard(
                child: SwitchListTile(
                  value: _withDescriptions,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _withDescriptions = v),
                  title: const Text('Açıklamaları da gönder'),
                  subtitle: const Text(
                    'Kapalıyken yalnızca tutar ve vade gider; notlarınız '
                    'sizde kalır.',
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (approval)
                    note(
                      Icons.handshake_outlined,
                      '$name onaylayınca ortak bakiyeye işlenir. '
                      'Onaylamazsa bakiyeye girmez.',
                    ),
                  if (mine)
                    note(
                      Icons.bolt_rounded,
                      'Kendi borcunuz onay beklemeden işlenir.',
                    ),
                  note(
                    Icons.inventory_2_outlined,
                    'Bu özel defter arşive alınır. Eski kayıtlarınızı '
                    'yalnızca siz görmeye devam edersiniz.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _query.text.trim().isNotEmpty && found == null
                            ? 'Kişiyi bul'
                            : 'Ortak deftere taşı',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
