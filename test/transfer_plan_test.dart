import 'package:flutter_test/flutter_test.dart';
import 'package:pacta/core/dates/local_date.dart';
import 'package:pacta/features/ledger/application/providers.dart';
import 'package:pacta/features/ledger/domain/models.dart';
import 'package:pacta/features/ledger/domain/summary.dart';
import 'package:pacta/features/ledger/domain/transfer_plan.dart';

Ledger private(
  Map<String, int> balances, {
  List<Map<String, Object?>> due = const [],
  String? convertedTo,
}) => Ledger.fromMap('v_bakkal', {
  'mode': 'private',
  if (convertedTo != null) ...{'status': 'closed', 'convertedTo': convertedTo},
  'sides': {
    'a': {'uid': 'gokhan', 'displayName': 'Gökhan'},
    'b': {'uid': null, 'displayName': 'Bakkal Ahmet'},
  },
  'balances': balances,
  'pendingCount': 0,
  'dueItems': due,
});

Map<String, Object?> dueItem(int open, String dueOn, [String note = '']) => {
  'entryId': 'e-$dueOn',
  'asset': 'TRY',
  'debtorSide': 'b',
  'openMinor': open,
  'dueOn': dueOn,
  'description': note,
};

void main() {
  test('vadeli parçalar ayrı, kalanı vadesiz; notlar istenmezse gitmez', () {
    final ledger = private(
      {'TRY': 80000},
      due: [dueItem(30000, '2026-10-01', 'Veresiye')],
    );
    final lines = transferPlan(ledger, withDescriptions: false);
    expect(lines.map((l) => l.amount.minor), [30000, 50000]);
    expect(lines.first.dueOn, const LocalDate(2026, 10, 1));
    expect(lines.last.dueOn, isNull);
    expect(lines.map((l) => l.description), [
      'Önceki kayıtlardan aktarıldı',
      'Önceki kayıtlardan kalan bakiye',
    ]);
    expect(lines.every((l) => l.needsApproval), isTrue);

    final withNotes = transferPlan(ledger, withDescriptions: true);
    expect(withNotes.first.description, 'Veresiye');
  });

  test('sahibin borcu onay beklemez; birimler ayrı', () {
    final lines = transferPlan(
      private({'TRY': -70000, 'USD': -1000}),
      withDescriptions: false,
    );
    expect(lines.map((l) => l.amount.asset.code), ['TRY', 'USD']);
    expect(lines.map((l) => l.amount.minor), [-70000, -1000]);
    expect(lines.any((l) => l.needsApproval), isFalse);
  });

  test('birim başına en fazla 10 vade; denk bakiye gitmez', () {
    final lines = transferPlan(
      private(
        {'TRY': 1200, 'EUR': 0},
        due: [
          for (var i = 0; i < 12; i++)
            dueItem(100, '2026-10-${(10 + i).toString().padLeft(2, '0')}'),
        ],
      ),
      withDescriptions: false,
    );
    expect(lines.length, 11);
    expect(lines.where((l) => l.dueOn != null).length, maxTransferDue);
    expect(lines.last.amount.minor, 200);
  });

  test('taşınmış özel defter listelere ve toplamlara girmez', () {
    final archived = private({'TRY': 99900}, convertedTo: 'p_ayse');
    final active = private({'TRY': 1000});
    expect(archived.isArchived, isTrue);
    expect(archived.isClosed, isTrue);
    expect(visibleLedgers([archived, active]), [active]);
    final totals = Totals.from([archived, active], 'gokhan');
    // Özel defter onaylı bakiyeye girmez; ayrı satırda gösterilir.
    expect(totals.receivable.minor, 0);
    expect(totals.private.single.minor, 1000);
  });
}
