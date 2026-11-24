import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/core/dates/local_date.dart';
import 'package:pacta/core/money/asset.dart';
import 'package:pacta/core/money/money.dart';
import 'package:pacta/features/ledger/data/statement_pdf.dart';
import 'package:pacta/features/ledger/domain/models.dart';
import 'package:pacta/features/ledger/domain/statement.dart';

// Gökhan (a) ile Ayşe Yılmaz (b). Defterdeki onaylı bakiye, aşağıdaki
// onaylı kayıtların toplamıdır: TRY 1260, USD -15, GAU 5 gram.
final ledger = Ledger.fromMap('p_ayse', {
  'mode': 'shared',
  'sides': {
    'a': {'uid': 'gokhan', 'displayName': 'Gökhan'},
    'b': {'uid': 'ayse', 'displayName': 'Ayşe Yılmaz'},
  },
  'balances': {'TRY': 126000, 'USD': -1500, 'GAU': 5000},
  'pendingCount': 2,
});

LedgerEntry entry(
  String id,
  String occurredOn,
  int delta, {
  String state = 'confirmed',
  String kind = 'debt',
  String asset = 'TRY',
  String? reversedBy,
  String? linkedEntryId,
}) => LedgerEntry.fromMap(id, {
  'ledgerId': 'p_ayse',
  'kind': kind,
  'direction': delta > 0 ? 'aToB' : 'bToA',
  'asset': asset,
  'amountMinor': delta.abs(),
  'deltaMinor': delta,
  'occurredOn': occurredOn,
  'description': id,
  'state': state,
  'version': 1,
  'proposedBy': 'a',
  'reversedBy': ?reversedBy,
  'linkedEntryId': ?linkedEntryId,
});

final entries = [
  // Dönemden önce (Ağustos öncesi).
  entry('r1', '2026-07-15', 100000),
  entry('r12', '2026-07-20', 20000, reversedBy: 'r13'),
  entry('r14', '2026-07-25', 3000, state: 'pending'),
  entry('r2', '2026-07-31', -2000, asset: 'USD'),
  // Ağustos: ilk ve son gün dahil.
  entry('r3', '2026-08-01', 50000),
  entry('r13', '2026-08-05', -20000, kind: 'reversal', linkedEntryId: 'r12'),
  entry('r4', '2026-08-10', -35000, kind: 'payment'),
  entry('r5', '2026-08-12', 5000, asset: 'GAU'),
  entry('r6', '2026-08-15', 7000, state: 'pending'),
  entry('r7', '2026-08-20', 9000, state: 'disputed'),
  entry('r8', '2026-08-21', 4000, state: 'rejected'),
  entry('r9', '2026-08-22', 1000, state: 'cancelled', asset: 'USD'),
  entry('r10', '2026-08-31', 500, asset: 'USD'),
  // Dönemden sonra.
  entry('r11', '2026-09-01', 11000),
];

const august = StatementPeriod(LocalDate(2026, 8, 1), LocalDate(2026, 8, 31));

List<(String, int, int, int)> rows(List<PeriodBalance> list) => [
  for (final b in list)
    (b.asset.code, b.opening.minor, b.movement.minor, b.closing.minor),
];

/// CSV'deki düz tutarı ("-1200,50") küçük birime çevirir.
int minorOf(String text, String code) {
  final negative = text.startsWith('-');
  final value = Money.parse(
    negative ? text.substring(1) : text,
    Asset.fromCode(code),
  ).minor;
  return negative ? -value : value;
}

/// Her birimde: devreden + dönemdeki onaylı satırlar = dönem sonu; son
/// satırın yürüyen bakiyesi de dönem sonudur.
void expectBalanced(Statement st) {
  for (final b in st.summary) {
    expect(b.opening + b.movement, b.closing, reason: b.asset.code);
    final lines = st.confirmed.where((l) => l.entry.asset == b.asset);
    final sum = lines.fold(0, (s, l) => s + l.amount.minor);
    expect(sum, b.movement.minor, reason: b.asset.code);
    if (lines.isNotEmpty) {
      expect(lines.last.balance, b.closing, reason: b.asset.code);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('dönem', () {
    test('iki uç dahil', () {
      expect(august.contains(const LocalDate(2026, 8, 1)), isTrue);
      expect(august.contains(const LocalDate(2026, 8, 31)), isTrue);
      expect(august.contains(const LocalDate(2026, 7, 31)), isFalse);
      expect(august.contains(const LocalDate(2026, 9, 1)), isFalse);
      expect(august.label, '01.08.2026 - 31.08.2026');
      expect(august.fileTag, '2026-08-01_2026-08-31');
    });

    test('hazır seçenekler', () {
      const today = LocalDate(2026, 11, 24);
      expect(PeriodChoice.all.periodFor(today), isNull);
      expect(PeriodChoice.custom.periodFor(today), isNull);
      expect(
        PeriodChoice.thisMonth.periodFor(today),
        const StatementPeriod(LocalDate(2026, 11, 1), today),
      );
      expect(
        PeriodChoice.lastMonth.periodFor(today),
        const StatementPeriod(LocalDate(2026, 10, 1), LocalDate(2026, 10, 31)),
      );
      expect(
        PeriodChoice.last3Months.periodFor(today),
        const StatementPeriod(LocalDate(2026, 8, 25), today),
      );
      // Ocak'ta geçen ay önceki yılın Aralık'ıdır; ay sonu taşmaz.
      expect(
        PeriodChoice.lastMonth.periodFor(const LocalDate(2027, 1, 10)),
        const StatementPeriod(LocalDate(2026, 12, 1), LocalDate(2026, 12, 31)),
      );
      expect(
        PeriodChoice.last3Months.periodFor(const LocalDate(2026, 5, 31)),
        const StatementPeriod(LocalDate(2026, 3, 1), LocalDate(2026, 5, 31)),
      );
    });
  });

  group('devreden ve dönem sonu bakiye', () {
    test('birim başına, birimler karışmadan', () {
      expect(rows(periodBalances(entries, Side.a, august)), [
        // Düzeltilen kayıt (r12) önceki dönemde +200, düzeltmesi (r13) bu
        // dönemde -200 olarak girer; bekleyen r14 hiç girmez.
        ('TRY', 120000, -5000, 115000),
        ('USD', -2000, 500, -1500),
        ('GAU', 0, 5000, 5000),
      ]);
    });

    test('karşı taraftan bakınca işaretler döner', () {
      expect(rows(periodBalances(entries, Side.b, august)), [
        ('TRY', -120000, 5000, -115000),
        ('USD', 2000, -500, 1500),
        ('GAU', 0, -5000, -5000),
      ]);
    });

    test('dönem içinde yalnızca dönemin kayıtları; yürüyen bakiye '
        'devredenden başlar', () {
      final st = Statement.of(ledger, entries, 'gokhan', period: august);
      expect(st.all.map((e) => e.id), [
        'r3',
        'r13',
        'r4',
        'r5',
        'r6',
        'r7',
        'r8',
        'r9',
        'r10',
      ]);
      expect(st.confirmed.map((l) => (l.entry.id, l.balance.minor)), [
        ('r3', 170000),
        ('r13', 150000),
        ('r4', 115000),
        ('r5', 5000),
        ('r10', -1500),
      ]);
      // Dönem dışındaki bekleyen (r14) listelenmez.
      expect(st.open.map((e) => e.id), ['r6', 'r7']);
      expect(st.closedCount, 2);
      expectBalanced(st);
    });

    test('bugüne kadar süren dönemde dönem sonu = defterin bakiyesi', () {
      for (final uid in ['gokhan', 'ayse']) {
        final st = Statement.of(
          ledger,
          entries,
          uid,
          period: PeriodChoice.thisMonth.periodFor(const LocalDate(2026, 9, 1)),
        );
        expectBalanced(st);
        expect(
          {for (final b in st.summary) b.asset: b.closing},
          {for (final m in ledger.balancesFor(uid)) m.asset: m},
        );
      }
    });

    test('ardışık dönemler: birinin sonu sonrakinin devredenidir', () {
      const july = StatementPeriod(
        LocalDate(2026, 7, 1),
        LocalDate(2026, 7, 31),
      );
      final first = periodBalances(entries, Side.a, july);
      final second = periodBalances(entries, Side.a, august);
      for (final b in first) {
        final next = second.firstWhere((x) => x.asset == b.asset);
        expect(next.opening, b.closing);
      }
    });

    test('boş dönem: kayıt yok, devreden = dönem sonu', () {
      const quiet = StatementPeriod(
        LocalDate(2026, 8, 23),
        LocalDate(2026, 8, 30),
      );
      final st = Statement.of(ledger, entries, 'gokhan', period: quiet);
      expect(st.all, isEmpty);
      expect(st.confirmed, isEmpty);
      expect(rows(st.summary), [
        ('TRY', 115000, 0, 115000),
        ('USD', -2000, 0, -2000),
        ('GAU', 5000, 0, 5000),
      ]);
      expectBalanced(st);
    });

    test('hiç onaylı kaydı olmayan defterde özet boş', () {
      final st = Statement.of(
        ledger,
        [entry('p', '2026-08-02', 1000, state: 'pending')],
        'gokhan',
        period: august,
      );
      expect(st.summary, isEmpty);
      expect(st.open.map((e) => e.id), ['p']);
    });
  });

  group('CSV', () {
    test('dönem satırı, devreden ve dönem sonu bakiye', () {
      final csv = Statement.of(
        ledger,
        entries,
        'gokhan',
        period: august,
      ).toCsv();
      expect(csv.startsWith('﻿Dönem;01.08.2026 - 31.08.2026\r\n'), isTrue);
      final lines = csv.substring(1).trim().split('\r\n');
      expect(lines[1], startsWith('İşlem tarihi;Kayıt;'));
      expect(lines.sublist(2, 5), [
        '01.08.2026;Devreden bakiye;;TRY;1200,00;1200,00;;;',
        '01.08.2026;Devreden bakiye;;USD;-20,00;-20,00;;;',
        '01.08.2026;Devreden bakiye;;GAU;0,000;0,000;;;',
      ]);
      expect(lines.sublist(lines.length - 3), [
        '31.08.2026;Dönem sonu bakiye;;TRY;1150,00;;;;',
        '31.08.2026;Dönem sonu bakiye;;USD;-15,00;;;;',
        '31.08.2026;Dönem sonu bakiye;;GAU;5,000;;;;',
      ]);
      expect(lines.length, 2 + 3 + 9 + 3);
      // Bekleyen kaydın etkisi 0.
      expect(lines.firstWhere((l) => l.contains(';r6;')), contains(';0,00;'));

      // "Bakiyeye etki" sütunu birim başına toplanınca dönem sonunu verir.
      final sums = <String, int>{};
      for (final l in lines.skip(2)) {
        final c = l.split(';');
        if (c[5].isEmpty) continue;
        sums[c[3]] = (sums[c[3]] ?? 0) + minorOf(c[5], c[3]);
      }
      expect(sums, {'TRY': 115000, 'USD': -1500, 'GAU': 5000});
    });

    test('boş dönem: geçerli dosya', () {
      final csv = Statement.of(
        ledger,
        const [],
        'gokhan',
        period: august,
      ).toCsv();
      final lines = csv.substring(1).trim().split('\r\n');
      expect(lines.length, 2);
      expect(lines.first, 'Dönem;01.08.2026 - 31.08.2026');
    });

    test('dosya adı dönemi taşır', () {
      final st = Statement.of(ledger, entries, 'gokhan', period: august);
      expect(
        st.fileName(const LocalDate(2026, 11, 24)),
        'pacta-ayse-yilmaz-2026-08-01_2026-08-31',
      );
      expect(st.fileName(const LocalDate(2026, 11, 24)), isNot(contains(' ')));
    });
  });

  test('PDF: dönemli ve boş dönem üretilir', () async {
    for (final period in [
      august,
      const StatementPeriod(LocalDate(2026, 8, 23), LocalDate(2026, 8, 30)),
    ]) {
      final bytes = await buildStatementPdf(
        Statement.of(ledger, entries, 'gokhan', period: period),
        now: DateTime(2026, 11, 24, 10, 0),
      );
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    }
  });
}
