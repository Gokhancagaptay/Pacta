import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../profile/profile_providers.dart';
import '../application/providers.dart';
import '../data/statement_pdf.dart';
import '../domain/models.dart';
import '../domain/people_summary.dart';
import '../domain/statement.dart';
import 'common.dart';

enum ExportFormat { pdf, csv }

/// Kişiyle hesabın dökümünü (PDF ekstre ya da CSV tablo) hazırlar ve
/// paylaşım menüsünü açar: kaydet, e-postayla ya da WhatsApp'tan gönder.
/// Dosya cihazda üretilir; sunucuya gönderilmez.
Future<void> exportStatement(
  BuildContext context,
  WidgetRef ref,
  Ledger ledger,
  ExportFormat format,
) async {
  final uid = ref.read(currentUidProvider);
  final entries = ref.read(entriesProvider(ledger.id)).valueOrNull;
  if (entries == null) {
    showSnack(context, 'Kayıtlar yükleniyor; birazdan tekrar deneyin.');
    return;
  }
  final st = Statement.of(ledger, entries, uid);
  await _share(
    context,
    name: st.fileName(ref.read(todayProvider)),
    format: format,
    subject: 'Pacta hesap ekstresi · ${st.other.displayName}',
    pdf: () => buildStatementPdf(st, now: DateTime.now()),
    csv: st.toCsv,
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
  );
  final owner = ref.read(userProfileProvider).valueOrNull?.adSoyad ?? '';
  await _share(
    context,
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
  required String name,
  required ExportFormat format,
  required String subject,
  required Future<Uint8List> Function() pdf,
  required String Function() csv,
}) async {
  try {
    final (Uint8List bytes, String file, String mime) = switch (format) {
      ExportFormat.pdf => (await pdf(), '$name.pdf', 'application/pdf'),
      ExportFormat.csv => (
        Uint8List.fromList(utf8.encode(csv())),
        '$name.csv',
        'text/csv',
      ),
    };
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mime, name: file)],
        fileNameOverrides: [file],
        subject: subject,
      ),
    );
  } catch (_) {
    if (context.mounted) {
      showSnack(context, 'Dosya hazırlanamadı. Tekrar deneyin.', error: true);
    }
  }
}
