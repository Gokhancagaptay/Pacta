import 'package:flutter_test/flutter_test.dart';
import 'package:pacta/core/dates/local_date.dart';
import 'package:pacta/core/money/asset.dart';
import 'package:pacta/core/ui/widgets.dart';
import 'package:pacta/features/ledger/application/providers.dart';
import 'package:pacta/features/ledger/domain/entry_text.dart';
import 'package:pacta/features/ledger/domain/models.dart';

Ledger ledger({
  Map<String, int> balances = const {},
  String a = 'gokhan',
  String b = 'ayse',
}) => Ledger.fromMap('p_x', {
  'mode': 'shared',
  'sides': {
    'a': {'uid': a, 'displayName': 'Gökhan'},
    'b': {'uid': b, 'displayName': 'Ayşe Yılmaz'},
  },
  'balances': balances,
  'pendingCount': 0,
});

LedgerEntry entry({
  String kind = 'debt',
  String direction = 'aToB',
  int amount = 40000,
  String state = 'pending',
  String proposedBy = 'a',
  String? awaiting = 'b',
  Map<String, Object?> extra = const {},
}) => LedgerEntry.fromMap('e1', {
  'ledgerId': 'p_x',
  'kind': kind,
  'direction': direction,
  'asset': 'TRY',
  'amountMinor': amount,
  'deltaMinor': direction == 'aToB' ? amount : -amount,
  'occurredOn': '2026-09-22',
  'dueOn': '2026-10-05',
  'description': 'Konser bileti',
  'state': state,
  'version': 1,
  'proposedBy': proposedBy,
  'proposedByUid': proposedBy == 'a' ? 'gokhan' : 'ayse',
  'awaitingSide': awaiting,
  ...extra,
});

void main() {
  group('Ledger bakış açısı', () {
    test('b tarafı bakiyeyi ters işaretle görür', () {
      final l = ledger(balances: {'TRY': 120000, 'CEYREK': -2});
      expect(l.balanceFor('gokhan').minor, 120000);
      expect(l.balanceFor('ayse').minor, -120000);
      expect(l.other('gokhan').displayName, 'Ayşe Yılmaz');
      expect(l.sideOf('mallory'), isNull);
      expect(l.balancesFor('ayse').map((m) => m.format()), [
        '−1.200,00 ₺',
        '2 çeyrek',
      ]);
    });
  });

  group('EntryText', () {
    test('karşı tarafın gözünden cümleler', () {
      // Gökhan (a) Ayşe'ye borç verdi.
      expect(
        EntryText.sentence(entry(), Side.b, 'Gökhan'),
        'Gökhan size 400,00 ₺ borç yazdı.',
      );
      expect(
        EntryText.sentence(entry(), Side.a, 'Ayşe Yılmaz'),
        'Borç verdiğinizi kaydettiniz: 400,00 ₺.',
      );
      // Ayşe (b) ödeme yaptığını bildirdi: değer b'den a'ya.
      final payment = entry(
        kind: 'payment',
        direction: 'bToA',
        proposedBy: 'b',
        awaiting: 'a',
      );
      expect(
        EntryText.sentence(payment, Side.a, 'Ayşe Yılmaz'),
        'Ayşe Yılmaz size 400,00 ₺ ödeme yaptığını bildirdi.',
      );
      expect(EntryText.title(payment, Side.a), 'Ödeme aldınız');
      expect(EntryText.title(payment, Side.b), 'Ödeme yaptınız');
      expect(EntryText.title(entry(), Side.b), 'Borç aldınız');
    });

    test('durum etiketleri', () {
      expect(EntryText.status(entry(), Side.b).label, 'Onayınız bekleniyor');
      expect(
        EntryText.status(entry(), Side.a).label,
        'Karşı tarafın onayı bekleniyor',
      );
      final disputed = entry(state: 'disputed', awaiting: 'a');
      expect(EntryText.status(disputed, Side.a).tone, ChipTone.dispute);
      expect(disputed.awaits(Side.a), isTrue);
      final confirmed = entry(state: 'confirmed', awaiting: null);
      expect(EntryText.status(confirmed, Side.b).label, 'Onaylı');
      expect(confirmed.canBeReversed, isTrue);
      final reversed = entry(
        state: 'confirmed',
        awaiting: null,
        extra: {'reversedBy': 'r1'},
      );
      expect(EntryText.status(reversed, Side.a).label, 'Düzeltildi');
      expect(reversed.canBeReversed, isFalse);
    });
  });

  group('Totals', () {
    test('TL alacak/borç ayrı, diğer birimler cümlede', () {
      final ledgers = [
        ledger(balances: {'TRY': 120000}),
        ledger(balances: {'TRY': 75000}, a: 'deniz', b: 'gokhan'),
        ledger(balances: {'TRY': 200000, 'CEYREK': 2}),
      ];
      final t = Totals.from(ledgers, 'gokhan');
      expect(t.receivable.minor, 320000);
      expect(t.payable.minor, 75000);
      expect(t.net.minor, 245000);
      expect(t.othersSentence, 'Ayrıca 2 çeyrek alacağınız var.');
      expect(Totals.from(const [], 'gokhan').othersSentence, isNull);
      expect(Asset.fromCode('TRY'), Asset.tryLira);
    });

    test('özel ve kapalı defterler onaylı bakiyeye girmez', () {
      final private = Ledger.fromMap('v_x', {
        'mode': 'private',
        'sides': {
          'a': {'uid': 'gokhan', 'displayName': 'Gökhan'},
          'b': {'uid': null, 'displayName': 'Bakkal'},
        },
        'balances': {'TRY': 80000},
      });
      final deleted = Ledger.fromMap('p_x', {
        'mode': 'shared',
        'status': 'closed',
        'sides': {
          'a': {'uid': 'gokhan', 'displayName': 'Gökhan'},
          'b': {'uid': 'eski', 'displayName': 'Silinmiş', 'deleted': true},
        },
        'balances': {'TRY': 50000},
      });
      final t = Totals.from([
        ledger(balances: {'TRY': 1000}),
        private,
        deleted,
      ], 'gokhan');
      expect(t.receivable.minor, 1000);
      expect(t.private.single.minor, 80000);
      expect(
        t.footnote,
        'Özel defterlerinizde ayrıca 800,00 ₺ alacağınız var '
        '(karşı taraf onaylamadı).',
      );
    });

    test('bozuk alanlar listeyi düşürmez', () {
      expect(LocalDate.tryParse('2026-13'), isNull);
      expect(Asset.tryFromCode('GBP'), isNull);
      final l = Ledger.fromMap('p_y', {
        'mode': 'shared',
        'sides': {
          'a': {'uid': 'gokhan', 'displayName': 'Gökhan'},
          'b': {'uid': 'x', 'displayName': 'X'},
        },
        'balances': {'TRY': 100, 'GBP': 5},
        'dueItems': [
          {
            'entryId': 'e1',
            'asset': 'GBP',
            'debtorSide': 'b',
            'openMinor': 5,
            'dueOn': '2026-10-01',
          },
          {
            'entryId': 'e2',
            'asset': 'TRY',
            'debtorSide': 'b',
            'openMinor': 100,
            'dueOn': 'yarın',
          },
          {
            'entryId': 'e3',
            'asset': 'TRY',
            'debtorSide': 'b',
            'openMinor': 100,
            'dueOn': '2026-10-01',
          },
        ],
      });
      expect(l.dueItems.map((i) => i.entryId), ['e3']);
      expect(l.balancesFor('gokhan').single.minor, 100);
    });
  });
}
