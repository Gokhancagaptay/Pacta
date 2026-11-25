import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/report.dart';
import '../ledger/application/providers.dart';
import '../ledger/presentation/common.dart';
import '../ledger/presentation/statement_export.dart';
import 'data_export.dart';
import 'data_export_firestore.dart';

/// Dışa aktarma okumalarının kaynağı; testler sahtesini verir.
final dataExportSourceProvider = Provider<DataExportSource>(
  (ref) => FirestoreDataExportSource(),
);

/// Bu sayıdan çok belgede JSON ayrı bir isolate'te yazılır (ekran donmasın).
const _isolateThreshold = 2000;

/// Hazırlama sürerken ikinci dokunuş yeni bir pencere açmasın.
bool _exportBusy = false;

/// "Verilerimi indir": önce dosyanın içeriği anlatılır, onaylanırsa veriler
/// sunucudan okunur, dosya cihazda hazırlanır ve paylaşım menüsü açılır.
Future<void> exportMyData(BuildContext context, WidgetRef ref) async {
  if (_exportBusy) return;
  _exportBusy = true;
  try {
    final ok = await showDataExportInfo(context);
    if (ok != true || !context.mounted) return;
    final uid = ref.read(currentUidProvider);
    final source = ref.read(dataExportSourceProvider);
    final sink = ref.read(exportSinkProvider);
    final outcome = await showDialog<_Outcome>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DataExportDialog(uid: uid, source: source),
    );
    if (!context.mounted || outcome == null) return;
    final file = outcome.file;
    if (file == null) {
      showSnack(context, outcome.error!, error: true);
      return;
    }
    try {
      await sink(file);
    } catch (e, st) {
      reportError(e, st, reason: 'Paylaşım menüsü açılamadı');
      if (context.mounted) {
        showSnack(context, 'Paylaşım açılamadı. Tekrar deneyin.', error: true);
      }
    }
  } finally {
    _exportBusy = false;
  }
}

/// Dosyanın neleri içerdiğini anlatan panel. "Dosyayı hazırla" ile true.
Future<bool?> showDataExportInfo(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) {
        final c = sheet.pacta;
        final text = Theme.of(sheet).textTheme;
        Widget line(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(s, style: text.bodyMedium),
        );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verilerimi indir',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                line(
                  'Hesap bilgileriniz, profiliniz, taraf olduğunuz tüm '
                  'defterler ve kayıtları (eski sürümleri ve geçmişiyle), '
                  'gelen kutunuz ve bildirimleriniz tek bir dosyada (JSON) '
                  'toplanır.',
                ),
                line(
                  'Ortak defterlerde karşı tarafın adı ve e-postası da '
                  'dosyada yer alır; bunlar defter kaydınızın parçasıdır.',
                ),
                line(
                  'Dosyada olmayan veriler ve nedenleri dosyanın sonunda '
                  'yazar.',
                ),
                Text(
                  'Dosya bu telefonda hazırlanır. İnternet bağlantısı '
                  'gerekir; kayıt sayısına göre biraz sürebilir.',
                  style: text.bodySmall?.copyWith(color: c.muted),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () => Navigator.of(sheet).pop(false),
                        child: const Text('Vazgeç'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () => Navigator.of(sheet).pop(true),
                        child: const Text('Dosyayı hazırla'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

/// Hazır dosya ya da kullanıcıya gösterilecek hata.
typedef _Outcome = ({ExportFile? file, String? error});

/// Okuma sürerken ilerlemeyi gösterir; bitince dosyayla kapanır.
/// "Vazgeç" (ya da geri tuşu) okumayı bir sonraki adımda durdurur.
class _DataExportDialog extends StatefulWidget {
  const _DataExportDialog({required this.uid, required this.source});

  final String uid;
  final DataExportSource source;

  @override
  State<_DataExportDialog> createState() => _DataExportDialogState();
}

class _DataExportDialogState extends State<_DataExportDialog> {
  DataExportProgress _progress = const DataExportProgress(
    ledgersDone: 0,
    ledgersTotal: null,
    documents: 0,
  );
  bool _cancelled = false;
  bool _writing = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    _Outcome? outcome;
    try {
      final data = await DataExportCollector(widget.source).collect(
        widget.uid,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        isCancelled: () => _cancelled,
      );
      if (_cancelled) throw const DataExportCancelled();
      if (mounted) setState(() => _writing = true);
      final now = DateTime.now();
      final map = buildDataExport(data, uid: widget.uid, now: now);
      final bytes = data.documentCount > _isolateThreshold
          ? await compute(encodeDataExport, map)
          : encodeDataExport(map);
      outcome = (
        file: (
          name: dataExportFileName(now),
          mime: 'application/json',
          bytes: bytes,
          subject: 'Pacta verilerim',
        ),
        error: null,
      );
    } on DataExportCancelled {
      outcome = null;
    } on DataExportException catch (e) {
      outcome = (file: null, error: e.message);
    } catch (e, st) {
      reportError(e, st, reason: 'Veri dışa aktarma hazırlanamadı');
      outcome = (
        file: null,
        error: 'Dosya hazırlanamadı. Biraz sonra tekrar deneyin.',
      );
    }
    if (mounted) Navigator.of(context).pop(outcome);
  }

  void _cancel() {
    if (!_cancelled) setState(() => _cancelled = true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final text = Theme.of(context).textTheme;
    final status = _cancelled
        ? 'Durduruluyor...'
        : (_writing ? 'Dosya yazılıyor...' : _progress.label);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: AlertDialog(
        title: const Text('Verileriniz hazırlanıyor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: _writing ? 1 : _progress.fraction),
            const SizedBox(height: 12),
            Text(status, style: text.bodySmall?.copyWith(color: c.muted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _cancelled ? null : _cancel,
            child: const Text('Vazgeç'),
          ),
        ],
      ),
    );
  }
}
