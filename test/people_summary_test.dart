import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/core/dates/local_date.dart';
import 'package:pacta/features/ledger/data/statement_pdf.dart';
import 'package:pacta/features/ledger/domain/models.dart';
import 'package:pacta/features/ledger/domain/people_summary.dart';
import 'package:pacta/features/ledger/domain/summary.dart';

Ledger ledger(
  String id,
  String name,
  Map<String, int> balances, {
  int pending = 0,
  String? due,
}) => Ledger.fromMap(id, {
  'mode': 'shared',
  'sides': {
    'a': {'uid': 'gokhan', 'displayName': 'Gökhan'},
    'b': {'uid': id, 'displayName': name, 'email': '$id@example.com'},
  },
  'balances': balances,
  'pendingCount': pending,
  'dueItems': [
    if (due != null)
      {
        'entryId': 'e-$id',
        'asset': 'TRY',
        'debtorSide': 'b',
        'openMinor': balances['TRY'] ?? 0,
        'dueOn': due,
        'description': '',
      },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('tr_TR'));

  const today = LocalDate(2026, 9, 28);
  final rows = [
    PersonRow.of(
      ledger(
        'ayse',
        'Ayşe; Yılmaz',
        {'TRY': 120000},
        pending: 1,
        due: '2026-09-20',
      ),
      'gokhan',
      today,
    ),
    PersonRow.of(
      ledger('can', '=Can', {'TRY': -50050, 'USD': 1000}),
      'gokhan',
      today,
    ),
  ];
  final summary = PeopleSummary(
    rows: rows,
    totals: SummaryTotals.of(rows),
    filter: PeopleFilter.all,
  );

  test('CSV: satırlar, diğer birimler, kaçış ve formül koruması', () {
    final lines = summary.toCsv().trim().split('\r\n');
    expect(summary.toCsv().startsWith('\uFEFFKişi;E-posta;TL bakiye'), isTrue);
    expect(
      lines[1],
      '"Ayşe; Yılmaz";ayse@example.com;1200,00;;1;20.09.2026;Evet',
    );
    expect(lines[2], "'=Can;can@example.com;-500,50;10,00 USD;0;;");
    expect(summary.fileName(today), 'pacta-kisiler-2026-09-28');
    expect(utf8.encode(summary.toCsv()), isNotEmpty);
  });

  test('PDF üretilir', () async {
    final bytes = await buildPeopleSummaryPdf(
      summary,
      now: DateTime(2026, 9, 28, 10),
      ownerName: 'Gökhan',
    );
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
  });
}
