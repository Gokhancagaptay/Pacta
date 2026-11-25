import 'package:flutter_test/flutter_test.dart';
import 'package:pacta/features/ledger/domain/models.dart';
import 'package:pacta/features/ledger/presentation/entry_composer_page.dart';
import 'package:pacta/features/ledger/presentation/entry_detail_page.dart';

// a = gokhan, b = ayse. Pozitif bakiye: b, a'ya borçlu.
Ledger ledger(
  int tryBalance, {
  List<Map<String, Object?>> due = const [],
  String status = 'active',
}) => Ledger.fromMap('p_x', {
  'mode': 'shared',
  'status': status,
  'sides': {
    'a': {'uid': 'gokhan', 'displayName': 'Gökhan'},
    'b': {'uid': 'ayse', 'displayName': 'Ayşe'},
  },
  'balances': {'TRY': tryBalance},
  'pendingCount': 0,
  'dueItems': due,
});

LedgerEntry debt({
  String kind = 'debt',
  String state = 'confirmed',
  String? dueOn,
  String? reversedBy,
}) => LedgerEntry.fromMap('e1', {
  'ledgerId': 'p_x',
  'kind': kind,
  'direction': 'aToB',
  'asset': 'TRY',
  'amountMinor': 40000,
  'deltaMinor': 40000,
  'occurredOn': '2026-09-22',
  'dueOn': dueOn,
  'description': 'Kira',
  'state': state,
  'version': 1,
  'proposedBy': 'a',
  'proposedByUid': 'gokhan',
  'reversedBy': reversedBy,
});

void main() {
  test('alacaklı ödeme aldığını, borçlu ödeme yaptığını kaydeder', () {
    final creditor = payOptionFor(debt(), ledger(120000), Side.a)!;
    expect(creditor.mode, ComposerMode.received);
    expect(creditor.amount.minor, 40000);
    expect(creditor.label, 'Bu borç için ödeme aldım');

    final debtor = payOptionFor(debt(), ledger(120000), Side.b)!;
    expect(debtor.mode, ComposerMode.paid);
    expect(debtor.label, 'Bu borca ödeme yap');
  });

  test('önerilen tutar bakiyeyi ve açık vadeyi aşmaz', () {
    expect(payOptionFor(debt(), ledger(25000), Side.a)!.amount.minor, 25000);
    final partlyPaid = ledger(
      120000,
      due: [
        {
          'entryId': 'e1',
          'asset': 'TRY',
          'debtorSide': 'b',
          'openMinor': 10000,
          'dueOn': '2026-10-05',
          'description': 'Kira',
        },
      ],
    );
    expect(
      payOptionFor(debt(dueOn: '2026-10-05'), partlyPaid, Side.a)!.amount.minor,
      10000,
    );
  });

  test('kapanmış ya da uygun olmayan borca ödeme önerilmez', () {
    // Bakiye sıfır ya da ters yönde: borç ödenmiş.
    expect(payOptionFor(debt(), ledger(0), Side.a), isNull);
    expect(payOptionFor(debt(), ledger(-5000), Side.a), isNull);
    // Vadeli borç açık vadeler arasında değil: ödenmiş.
    expect(
      payOptionFor(debt(dueOn: '2026-10-05'), ledger(120000), Side.a),
      isNull,
    );
    expect(
      payOptionFor(debt(state: 'pending'), ledger(120000), Side.a),
      isNull,
    );
    expect(payOptionFor(debt(kind: 'payment'), ledger(120000), Side.a), isNull);
    expect(
      payOptionFor(debt(reversedBy: 'r1'), ledger(120000), Side.a),
      isNull,
    );
    expect(
      payOptionFor(debt(), ledger(120000, status: 'closed'), Side.a),
      isNull,
    );
  });
}
