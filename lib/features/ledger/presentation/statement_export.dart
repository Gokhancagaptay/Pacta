import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../application/providers.dart';
import '../data/statement_pdf.dart';
import '../domain/models.dart';
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
  final name = st.fileName(ref.read(todayProvider));
  try {
    final (Uint8List bytes, String file, String mime) = switch (format) {
      ExportFormat.pdf => (
        await buildStatementPdf(st, now: DateTime.now()),
        '$name.pdf',
        'application/pdf',
      ),
      ExportFormat.csv => (
        Uint8List.fromList(utf8.encode(st.toCsv())),
        '$name.csv',
        'text/csv',
      ),
    };
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mime, name: file)],
        fileNameOverrides: [file],
        subject: 'Pacta hesap ekstresi · ${st.other.displayName}',
      ),
    );
  } catch (_) {
    if (context.mounted) {
      showSnack(context, 'Dosya hazırlanamadı. Tekrar deneyin.', error: true);
    }
  }
}
