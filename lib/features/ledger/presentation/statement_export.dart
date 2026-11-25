import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/dates/local_date.dart';
import '../../../core/report.dart';
import '../../profile/profile_providers.dart';
import '../application/providers.dart';
import '../data/statement_pdf.dart';
import '../domain/models.dart';
import '../domain/people_summary.dart';
import '../domain/statement.dart';
import 'common.dart';

enum ExportFormat { pdf, csv }

/// Hazırlanmış dışa aktarma dosyası.
typedef ExportFile = ({
  String name,
  String mime,
  Uint8List bytes,
  String subject,
});

/// Hazır dosyayı kullanıcıya iletir (paylaşım menüsü). Paylaşım bir
/// eklentiyle çalışır ve testte çalışmaz; testler bunu değiştirip üretilen
/// dosyayı okur.
final exportSinkProvider = Provider<Future<void> Function(ExportFile file)>(
  (ref) => _shareFile,
);

Future<void> _shareFile(ExportFile f) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(f.bytes, mimeType: f.mime, name: f.name)],
      fileNameOverrides: [f.name],
      subject: f.subject,
    ),
  );
}

/// Kişiyle hesabın dökümünü (PDF ekstre ya da CSV tablo) hazırlar ve
/// paylaşım menüsünü açar: kaydet, e-postayla ya da WhatsApp'tan gönder.
/// Önce dönem sorulur (varsayılan: tüm kayıtlar). Dosya cihazda üretilir;
/// sunucuya gönderilmez.
Future<void> exportStatement(
  BuildContext context,
  WidgetRef ref,
  Ledger ledger,
  ExportFormat format,
) async {
  final uid = ref.read(currentUidProvider);
  final today = ref.read(todayProvider);
  final sink = ref.read(exportSinkProvider);
  if (ref.read(entriesProvider(ledger.id)).valueOrNull == null) {
    showSnack(context, 'Kayıtlar yükleniyor; birazdan tekrar deneyin.');
    return;
  }
  final choice = await pickStatementPeriod(context, today);
  if (choice == null || !context.mounted) return;
  // Seçim sürerken gelen kayıtlar da girsin: liste yeniden okunur.
  final entries = ref.read(entriesProvider(ledger.id)).valueOrNull;
  if (entries == null) {
    showSnack(context, 'Kayıtlar yükleniyor; birazdan tekrar deneyin.');
    return;
  }
  final st = Statement.of(ledger, entries, uid, period: choice.period);
  final period = choice.period;
  await _share(
    context,
    sink: sink,
    name: st.fileName(today),
    format: format,
    subject:
        'Pacta hesap ekstresi · ${st.other.displayName}'
        '${period == null ? '' : ' · ${period.label}'}',
    pdf: () => buildStatementPdf(st, now: DateTime.now()),
    csv: st.toCsv,
  );
}

/// Ekstrenin dönemini sorar. Vazgeçilirse null; "Tüm kayıtlar" seçilirse
/// dönemi null olan kayıt döner.
Future<({StatementPeriod? period})?> pickStatementPeriod(
  BuildContext context,
  LocalDate today,
) async {
  final choice = await showModalBottomSheet<PeriodChoice>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              'Hangi dönem?',
              style: Theme.of(sheet).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          for (final c in PeriodChoice.values)
            ListTile(
              title: Text(c.label),
              subtitle: switch (c.periodFor(today)) {
                final p? => Text(p.label),
                null => null,
              },
              trailing: c == PeriodChoice.custom
                  ? const Icon(Icons.date_range_rounded)
                  : null,
              onTap: () => Navigator.of(sheet).pop(c),
            ),
        ],
      ),
    ),
  );
  if (choice == null) return null;
  if (choice != PeriodChoice.custom) return (period: choice.periodFor(today));
  if (!context.mounted) return null;
  final range = await showDateRangePicker(
    context: context,
    locale: const Locale('tr', 'TR'),
    firstDate: DateTime(today.year - 50),
    lastDate: today.toDateTime(),
    initialDateRange: DateTimeRange(
      start: LocalDate(today.year, today.month, 1).toDateTime(),
      end: today.toDateTime(),
    ),
    helpText: 'Tarih aralığı seçin',
    saveText: 'Seç',
  );
  if (range == null) return null;
  return (
    period: StatementPeriod(
      LocalDate.fromDateTime(range.start),
      LocalDate.fromDateTime(range.end),
    ),
  );
}

/// Kişiler ekranında görünen satırların özeti (süzgeç uygulanmış).
Future<void> exportPeopleSummary(
  BuildContext context,
  WidgetRef ref,
  ExportFormat format,
) async {
  final selected = ref.read(selectedPersonRowsProvider).valueOrNull;
  if (selected == null || selected.rows.isEmpty) {
    showSnack(context, 'Dışa aktarılacak kişi yok.');
    return;
  }
  final summary = PeopleSummary(
    rows: selected.rows,
    totals: selected.totals,
    filter: ref.read(peopleFilterProvider),
    query: ref.read(peopleQueryProvider).trim(),
  );
  final owner = ref.read(userProfileProvider).valueOrNull?.adSoyad ?? '';
  await _share(
    context,
    sink: ref.read(exportSinkProvider),
    name: summary.fileName(ref.read(todayProvider)),
    format: format,
    subject: 'Pacta kişiler özeti',
    pdf: () =>
        buildPeopleSummaryPdf(summary, now: DateTime.now(), ownerName: owner),
    csv: summary.toCsv,
  );
}

Future<void> _share(
  BuildContext context, {
  required Future<void> Function(ExportFile file) sink,
  required String name,
  required ExportFormat format,
  required String subject,
  required Future<Uint8List> Function() pdf,
  required String Function() csv,
}) async {
  final Uint8List bytes;
  final String file;
  final String mime;
  try {
    (bytes, file, mime) = switch (format) {
      ExportFormat.pdf => (await pdf(), '$name.pdf', 'application/pdf'),
      ExportFormat.csv => (
        Uint8List.fromList(utf8.encode(csv())),
        '$name.csv',
        'text/csv',
      ),
    };
  } catch (e, st) {
    reportError(e, st, reason: 'Dışa aktarma dosyası hazırlanamadı');
    if (context.mounted) {
      showSnack(context, 'Dosya hazırlanamadı. Tekrar deneyin.', error: true);
    }
    return;
  }
  try {
    await sink((name: file, mime: mime, bytes: bytes, subject: subject));
  } catch (e, st) {
    // Dosya hazır; sorun paylaşım menüsünde.
    reportError(e, st, reason: 'Paylaşım menüsü açılamadı');
    if (context.mounted) {
      showSnack(context, 'Paylaşım açılamadı. Tekrar deneyin.', error: true);
    }
  }
}
