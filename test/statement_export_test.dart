import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/features/ledger/domain/models.dart';
import 'package:pacta/features/ledger/domain/statement.dart';
import 'package:pacta/features/ledger/presentation/ledger_page.dart';
import 'package:pacta/features/ledger/presentation/statement_export.dart';

import 'v2_screens_test.dart' show FakeRepo, app, ledgers, phoneSize;

// Can Demir defteri (onaylı bakiye 2000 ₺); testte bugün 25 Eylül 2026.
LedgerEntry entry(
  String id,
  String occurredOn,
  int delta, {
  String state = 'confirmed',
}) => LedgerEntry.fromMap(id, {
  'ledgerId': 'p_can',
  'kind': 'debt',
  'direction': 'aToB',
  'asset': 'TRY',
  'amountMinor': delta,
  'deltaMinor': delta,
  'occurredOn': occurredOn,
  'description': id,
  'state': state,
  'version': 1,
  'proposedBy': 'a',
});

final canEntries = [
  entry('temmuz', '2026-07-10', 150000),
  entry('agustos', '2026-08-05', 30000),
  entry('bekleyen', '2026-08-20', 5000, state: 'pending'),
  entry('eylul', '2026-09-24', 20000),
];

void main() {
  setUpAll(() async {
    PactaTheme.useGoogleFonts = false;
    await initializeDateFormatting('tr_TR');
  });

  /// Defter sayfasını açar; paylaşım yerine dosyaları [sent] listesine
  /// yazar (paylaşım menüsü eklentiyle çalışır, testte açılamaz).
  Future<List<ExportFile>> open(WidgetTester tester, String item) async {
    phoneSize(tester);
    final sent = <ExportFile>[];
    await tester.pumpWidget(
      app(
        ProviderScope(
          overrides: [
            exportSinkProvider.overrideWithValue((f) async => sent.add(f)),
          ],
          child: const LedgerPage(ledgerId: 'p_can'),
        ),
        FakeRepo(),
        entries: {'p_can': canEntries},
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Diğer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
    return sent;
  }

  /// UTF-8 BOM'dan (Excel) sonraki metin.
  String text(ExportFile f) {
    expect(f.bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    return utf8.decode(f.bytes.sublist(3));
  }

  testWidgets('Dönem sorulur; geçen ay devreden ve dönem sonuyla', (
    tester,
  ) async {
    final sent = await open(tester, 'Tablo (CSV)');
    expect(find.text('Hangi dönem?'), findsOneWidget);
    for (final c in PeriodChoice.values) {
      expect(find.text(c.label), findsOneWidget);
    }
    expect(find.text('01.08.2026 - 31.08.2026'), findsOneWidget);
    expect(sent, isEmpty);

    await tester.tap(find.text('Geçen ay'));
    await tester.pumpAndSettle();
    expect(sent, hasLength(1));
    final f = sent.single;
    expect(f.name, 'pacta-can-demir-2026-08-01_2026-08-31.csv');
    expect(f.mime, 'text/csv');
    expect(f.subject, endsWith(' · 01.08.2026 - 31.08.2026'));
    final lines = text(f).trim().split('\r\n');
    expect(lines.first, 'Dönem;01.08.2026 - 31.08.2026');
    expect(lines[2], '01.08.2026;Devreden bakiye;;TRY;1500,00;1500,00;;;');
    expect(lines.last, '31.08.2026;Dönem sonu bakiye;;TRY;1800,00;;;;');
    expect(lines.where((l) => l.contains(';agustos;')), hasLength(1));
    expect(lines.where((l) => l.contains(';bekleyen;')), hasLength(1));
    expect(lines.where((l) => l.contains(';temmuz;')), isEmpty);
    expect(lines.where((l) => l.contains(';eylul;')), isEmpty);
  });

  testWidgets('Tüm kayıtlar: bugünkü dosyanın aynısı', (tester) async {
    final sent = await open(tester, 'Tablo (CSV)');
    await tester.tap(find.text('Tüm kayıtlar'));
    await tester.pumpAndSettle();
    final f = sent.single;
    expect(f.name, 'pacta-can-demir-2026-09-25.csv');
    expect(f.subject, 'Pacta hesap ekstresi · Can Demir');
    final can = ledgers.firstWhere((l) => l.id == 'p_can');
    expect(
      f.bytes,
      utf8.encode(Statement.of(can, canEntries, 'gokhan').toCsv()),
    );
  });

  testWidgets('PDF: dönem dosya adında', (tester) async {
    final sent = await open(tester, 'Ekstre (PDF)');
    await tester.tap(find.text('Bu ay'));
    // PDF yazı tipi dosyadan okunur: gerçek zamanlı beklenir.
    for (var i = 0; i < 20 && sent.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }
    final f = sent.single;
    expect(f.name, 'pacta-can-demir-2026-09-01_2026-09-25.pdf');
    expect(f.mime, 'application/pdf');
    expect(ascii.decode(f.bytes.sublist(0, 5)), '%PDF-');
  });

  testWidgets('Panel kapatılırsa dosya hazırlanmaz', (tester) async {
    final sent = await open(tester, 'Ekstre (PDF)');
    expect(find.text('Hangi dönem?'), findsOneWidget);
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
    expect(find.text('Hangi dönem?'), findsNothing);
    expect(sent, isEmpty);
  });

  testWidgets('Tarih aralığı: seçiciden gelen dönem kullanılır', (
    tester,
  ) async {
    final sent = await open(tester, 'Tablo (CSV)');
    await tester.tap(find.text('Tarih aralığı seç'));
    await tester.pumpAndSettle();
    expect(find.text('Tarih aralığı seçin'), findsOneWidget);
    // Seçici bu ayın başından bugüne açılır; olduğu gibi onaylanır.
    await tester.tap(find.text('Seç'));
    await tester.pumpAndSettle();
    final f = sent.single;
    expect(f.name, 'pacta-can-demir-2026-09-01_2026-09-25.csv');
    final lines = text(f).trim().split('\r\n');
    expect(lines.first, 'Dönem;01.09.2026 - 25.09.2026');
    // Bugüne kadar süren dönemin sonu, defterin onaylı bakiyesidir.
    expect(lines.last, '25.09.2026;Dönem sonu bakiye;;TRY;2000,00;;;;');
  });

  testWidgets('Tarih seçiciden vazgeçilirse dosya hazırlanmaz', (tester) async {
    final sent = await open(tester, 'Tablo (CSV)');
    await tester.tap(find.text('Tarih aralığı seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
  });
}
