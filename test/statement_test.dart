import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/core/dates/local_date.dart';
import 'package:pacta/core/money/asset.dart';
import 'package:pacta/core/money/money.dart';
import 'package:pacta/features/ledger/data/statement_pdf.dart';
import 'package:pacta/features/ledger/domain/models.dart';
import 'package:pacta/features/ledger/domain/statement.dart';

// Gökhan (a) ile Ayşe Yılmaz (b); Gökhan b tarafından bakıyor olabilir.
final ledger = Ledger.fromMap('p_ayse', {
  'mode': 'shared',
  'sides': {
    'a': {'uid': 'gokhan', 'displayName': 'Gökhan', 'email': 'g@example.com'},
    'b': {
      'uid': 'ayse',
      'displayName': 'Ayşe Yılmaz',
      'email': 'ayse@example.com',
    },
  },
  'balances': {'TRY': 100000, 'USD': -500},
  'pendingCount': 1,
  'head': {'seq': 3, 'chainHash': 'abcdef0123456789abcdef'},
  'dueItems': [
    {
      'entryId': 'e1',
      'asset': 'TRY',
      'debtorSide': 'b',
      'openMinor': 100000,
      'dueOn': '2026-10-01',
      'description': 'Kira payı',
    },
  ],
});

LedgerEntry entry(
  String id,
  String occurredOn,
  int delta, {
  String state = 'confirmed',
  String kind = 'debt',
  String asset = 'TRY',
  String description = '',
  String? dueOn,
}) => LedgerEntry.fromMap(id, {
  'ledgerId': 'p_ayse',
  'kind': kind,
  'direction': delta > 0 ? 'aToB' : 'bToA',
  'asset': asset,
  'amountMinor': delta.abs(),
  'deltaMinor': delta,
  'occurredOn': occurredOn,
  'dueOn': dueOn,
  'description': description,
  'state': state,
  'version': 1,
  'proposedBy': 'a',
});

final entries = [
  // Sıra karışık gelir; ekstre işlem tarihine göre dizer.
  entry('e3', '2026-09-20', -20000, kind: 'payment', description: 'Havale'),
  entry(
    'e1',
    '2026-09-01',
    120000,
    description: 'Kira payı',
    dueOn: '2026-10-01',
  ),
  entry('e2', '2026-09-10', -500, asset: 'USD'),
  entry('e4', '2026-09-25', 5000, state: 'pending'),
  entry(
    'e5',
    '2026-09-26',
    7000,
    state: 'rejected',
    description: '=HYPERLINK()',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('tr_TR'));

  test('onaylılar tarihe göre, birim başına yürüyen bakiyeyle', () {
    final st = Statement.of(ledger, entries, 'gokhan');
    expect(st.confirmed.map((l) => l.entry.id), ['e1', 'e2', 'e3']);
    expect(st.confirmed.map((l) => l.balance.minor), [120000, -500, 100000]);
    expect(st.open.map((e) => e.id), ['e4']);
    expect(st.closedCount, 1);
    expect(st.balances.map((m) => (m.asset.code, m.minor)), [
      ('TRY', 100000),
      ('USD', -500),
    ]);
  });

  test('karşı taraftan bakınca işaretler döner', () {
    final st = Statement.of(ledger, entries, 'ayse');
    expect(st.other.displayName, 'Gökhan');
    expect(st.confirmed.first.amount.minor, -120000);
    expect(st.balances.first.minor, -100000);
  });

  test('CSV: Excel Türkçe biçimi, formül olarak çalışmaz', () {
    final csv = Statement.of(ledger, entries, 'gokhan').toCsv();
    expect(csv.startsWith('\uFEFFİşlem tarihi;Kayıt;'), isTrue);
    final lines = csv.trim().split('\r\n');
    expect(lines.length, 6);
    expect(
      lines[1],
      '01.09.2026;Borç verdiniz;Kira payı;TRY;1200,00;1200,00;Onaylı;'
      '01.10.2026;Gökhan',
    );
    // Onay bekleyen ve reddedilen kaydın bakiyeye etkisi 0: sütun toplamı
    // bakiyeyi verir.
    expect(lines[4], contains(';50,00;0,00;'));
    expect(lines[5], contains(';70,00;0,00;'));
    expect(lines[3], contains(';-200,00;'));
    expect(lines[5], contains(";'=HYPERLINK();"));
    expect(utf8.encode(csv), isNotEmpty);
  });

  test('düz tutar ve dosya adı', () {
    expect(plainAmount(const Money(-125050, Asset.tryLira)), '-1250,50');
    expect(plainAmount(Money(5, Asset.fromCode('GAU'))), '0,005');
    expect(plainAmount(Money(3, Asset.fromCode('CEYREK'))), '3');
    expect(
      Statement.of(
        ledger,
        entries,
        'gokhan',
      ).fileName(const LocalDate(2026, 9, 27)),
      'pacta-ayse-yilmaz-2026-09-27',
    );
  });

  test('PDF üretilir (gömülü yazı tipiyle, internetsiz)', () async {
    final bytes = await buildStatementPdf(
      Statement.of(ledger, entries, 'gokhan'),
      now: DateTime(2026, 9, 27, 14, 5),
    );
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(10000));
  });
}
