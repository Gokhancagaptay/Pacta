import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/core/dates/local_date.dart';
import 'package:pacta/features/ledger/domain/models.dart';
import 'package:pacta/features/ledger/domain/reminder.dart';
import 'package:pacta/features/ledger/domain/summary.dart';
import 'package:pacta/services/notification_routes.dart';

const today = LocalDate(2026, 9, 25);

Ledger ledger(
  String id,
  String otherName,
  int balance, {
  bool private = false,
  int pending = 0,
  List<Map<String, Object?>> due = const [],
  String? lastReminderOn,
}) => Ledger.fromMap(id, {
  'mode': private ? 'private' : 'shared',
  'sides': {
    'a': {'uid': 'me', 'displayName': 'Gökhan'},
    'b': {'uid': private ? null : 'u_$id', 'displayName': otherName},
  },
  'balances': {'TRY': balance},
  'pendingCount': pending,
  'dueItems': due,
  'reminders': {
    if (lastReminderOn != null) 'a': {'lastOn': lastReminderOn},
  },
});

Map<String, Object?> dueItem(String entryId, String side, int minor, String on) => {
  'entryId': entryId,
  'asset': 'TRY',
  'debtorSide': side,
  'openMinor': minor,
  'dueOn': on,
  'description': '',
};

LedgerEntry pendingFor(String side) => LedgerEntry.fromMap('e1', {
  'ledgerId': 'l',
  'kind': 'debt',
  'direction': 'aToB',
  'asset': 'TRY',
  'amountMinor': 100,
  'deltaMinor': 100,
  'occurredOn': '2026-09-25',
  'state': 'pending',
  'version': 1,
  'proposedBy': 'a',
  'awaitingSide': side,
});

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('ReminderPlan', () {
    test('konu sırası: vadesi geçmiş > yanıt bekleyen > açık bakiye', () {
      final overdue = ledger('x', 'Ayşe', 5000, due: [dueItem('e', 'b', 5000, '2026-09-20')]);
      expect(ReminderPlan.of(overdue, const [], 'me', today).kind, ReminderKind.overdue);

      final pending = ledger('x', 'Ayşe', 0);
      final plan = ReminderPlan.of(pending, [pendingFor('b')], 'me', today);
      expect(plan.kind, ReminderKind.pending);
      expect(plan.waiting, 1);

      expect(
        ReminderPlan.of(ledger('x', 'Ayşe', 5000), const [], 'me', today).kind,
        ReminderKind.balance,
      );
    });

    test('borçlu olan, kendi bekleyeni olan ve özel defter hatırlatamaz', () {
      expect(ReminderPlan.of(ledger('x', 'Ayşe', -5000), const [], 'me', today).isRelevant, isFalse);
      expect(
        ReminderPlan.of(ledger('x', 'Ayşe', 0), [pendingFor('a')], 'me', today).isRelevant,
        isFalse,
      );
      expect(
        ReminderPlan.of(ledger('x', 'Bakkal', 5000, private: true), const [], 'me', today).isRelevant,
        isFalse,
      );
    });

    test('yakın zamanda gönderildiyse bir sonraki gün hesaplanır', () {
      final recent = ledger('x', 'Ayşe', 5000, lastReminderOn: '2026-09-20');
      final plan = ReminderPlan.of(recent, const [], 'me', today);
      expect(plan.canSend, isFalse);
      expect(plan.nextOn, const LocalDate(2026, 9, 27));

      final old = ledger('x', 'Ayşe', 5000, lastReminderOn: '2026-09-18');
      expect(ReminderPlan.of(old, const [], 'me', today).canSend, isTrue);
    });

    test('metin sunucuyla aynı ve tutar içermez', () {
      final t = ReminderPlan.text(ReminderKind.balance, 'Gökhan', 0);
      expect(t.title, 'Hesap hatırlatması');
      expect(
        t.message,
        'Gökhan ile ortak hesabınızda açık bir bakiye görünüyor. '
        'Uygun olduğunuzda kontrol edebilirsiniz.',
      );
      for (final kind in ReminderKind.values) {
        expect(ReminderPlan.text(kind, 'Gökhan', 2).message, isNot(contains('₺')));
      }
    });
  });

  group('Hesap özeti', () {
    final rows = [
      PersonRow.of(
        ledger('a', 'Ayşe', 120000, due: [dueItem('e1', 'b', 50000, '2026-09-20')]),
        'me',
        today,
      ),
      PersonRow.of(ledger('c', 'Can', 200000, pending: 2), 'me', today),
      PersonRow.of(
        ledger('d', 'Deniz', -75000, due: [dueItem('e2', 'a', 75000, '2026-09-28')]),
        'me',
        today,
      ),
    ];

    test('süzgeçler', () {
      List<String> names(PeopleFilter f) =>
          [for (final r in selectRows(rows, filter: f)) r.name];
      expect(names(PeopleFilter.owesMe), ['Ayşe', 'Can']);
      expect(names(PeopleFilter.iOwe), ['Deniz']);
      expect(names(PeopleFilter.overdue), ['Ayşe']);
      expect(names(PeopleFilter.pending), ['Can']);
    });

    test('sıralama ve Türkçe arama', () {
      List<String> names(PeopleSort s) =>
          [for (final r in selectRows(rows, sort: s)) r.name];
      expect(names(PeopleSort.amount), ['Can', 'Ayşe', 'Deniz']);
      expect(names(PeopleSort.due), ['Ayşe', 'Deniz', 'Can']);
      expect([for (final r in selectRows(rows, query: 'AYŞ')) r.name], ['Ayşe']);
    });

    test('toplamlar', () {
      final t = SummaryTotals.of(rows);
      expect(t.receivable.minor, 320000);
      expect(t.payable.minor, 75000);
      expect(t.net.minor, 245000);
      expect(t.pendingCount, 2);
    });
  });

  group('Vade takvimi', () {
    test('gecikmiş, 30 gün ve sonrası ayrılır; tutar kullanıcının gözünden', () {
      final s = DueSchedule.of([
        ledger('a', 'Ayşe', 1, due: [
          dueItem('e1', 'b', 100, '2026-09-20'),
          dueItem('e3', 'b', 100, '2026-12-01'),
        ]),
        ledger('d', 'Deniz', -1, due: [dueItem('e2', 'a', 300, '2026-09-25')]),
      ], 'me', today);
      expect([for (final r in s.overdue) r.item.entryId], ['e1']);
      expect([for (final r in s.upcoming) r.item.entryId], ['e2']);
      expect([for (final r in s.later) r.item.entryId], ['e3']);
      expect(s.overdue.single.amount.minor, 100);
      expect(s.upcoming.single.amount.minor, -300);
      expect(s.upcoming.single.iOwe, isTrue);
    });

    test('göreli gün', () {
      expect(relativeDue(const LocalDate(2026, 9, 20), today), '5 gün geçti');
      expect(relativeDue(today, today), 'Bugün');
      expect(relativeDue(const LocalDate(2026, 9, 26), today), 'Yarın');
      expect(relativeDue(const LocalDate(2026, 9, 28), today), '3 gün sonra');
    });
  });

  test('bildirim rotası çözülür', () {
    expect(NotificationRoutes.parse('/l/p_a_b'), (ledgerId: 'p_a_b', entryId: null));
    expect(NotificationRoutes.parse('/l/p_a_b/e/e-1'), (ledgerId: 'p_a_b', entryId: 'e-1'));
    expect(NotificationRoutes.parse('/debts/x'), isNull);
  });
}
