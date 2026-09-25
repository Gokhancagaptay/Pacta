import '../../../core/dates/local_date.dart';
import '../../../core/money/asset.dart';
import '../../../core/money/money.dart';
import '../../../core/text/turkish.dart';
import 'models.dart';

// Hesap özeti (kişi tablosu) ve vade takvimi. Hepsi defter belgelerinden
// hesaplanır; ek okuma yapmaz.

/// Kişiler ekranındaki süzgeçler.
enum PeopleFilter {
  all('Tümü'),
  owesMe('Bana borçlu'),
  iOwe('Borçlu olduğum'),
  overdue('Vadesi geçen'),
  pending('Onay bekleyen');

  const PeopleFilter(this.label);
  final String label;
}

enum PeopleSort {
  recent('Son hareket'),
  amount('Tutar'),
  due('Vade'),
  name('İsim');

  const PeopleSort(this.label);
  final String label;
}

/// Tablodaki bir satır: kişiyle olan hesabın özeti, kullanıcının gözünden.
class PersonRow {
  const PersonRow({
    required this.ledger,
    required this.name,
    required this.balance,
    required this.others,
    required this.nextDue,
    required this.overdue,
  });

  factory PersonRow.of(Ledger ledger, String uid, LocalDate today) {
    final me = ledger.sideOf(uid) ?? Side.a;
    final due = ledger.dueItems;
    return PersonRow(
      ledger: ledger,
      name: ledger.other(uid).displayName,
      balance: ledger.balanceFor(uid),
      others: [
        for (final m in ledger.balancesFor(uid))
          if (m.asset != Asset.tryLira) m,
      ],
      nextDue: due.isEmpty ? null : due.first,
      overdue: due.where((i) => i.dueOn < today).map((i) => i.signedFor(me)).toList(),
    );
  }

  final Ledger ledger;
  final String name;

  /// TL bakiyesi (pozitif = size borçlu).
  final Money balance;

  /// TL dışındaki bakiyeler (altın, döviz).
  final List<Money> others;

  /// En yakın açık vade (geçmiş olabilir).
  final DueItem? nextDue;

  /// Vadesi geçmiş parçalar, kullanıcının gözünden işaretli.
  final List<Money> overdue;

  int get pendingCount => ledger.pendingCount;
  bool get owesMe => balance.minor > 0 || others.any((m) => m.minor > 0);
  bool get iOwe => balance.isNegative || others.any((m) => m.isNegative);
  bool get hasOverdue => overdue.isNotEmpty;

  bool matches(PeopleFilter filter) => switch (filter) {
    PeopleFilter.all => true,
    PeopleFilter.owesMe => owesMe,
    PeopleFilter.iOwe => iOwe,
    PeopleFilter.overdue => hasOverdue,
    PeopleFilter.pending => pendingCount > 0,
  };
}

/// Satırları arar, süzer ve sıralar.
List<PersonRow> selectRows(
  List<PersonRow> rows, {
  PeopleFilter filter = PeopleFilter.all,
  PeopleSort sort = PeopleSort.recent,
  String query = '',
}) {
  final q = trLower(query.trim());
  final list = [
    for (final r in rows)
      if (r.matches(filter) && (q.isEmpty || trLower(r.name).contains(q))) r,
  ];
  int byName(PersonRow x, PersonRow y) => trLower(x.name).compareTo(trLower(y.name));
  switch (sort) {
    case PeopleSort.recent:
      break; // defterler zaten son harekete göre gelir
    case PeopleSort.amount:
      list.sort((x, y) {
        final c = y.balance.minor.abs().compareTo(x.balance.minor.abs());
        return c != 0 ? c : byName(x, y);
      });
    case PeopleSort.due:
      list.sort((x, y) {
        final dx = x.nextDue?.dueOn;
        final dy = y.nextDue?.dueOn;
        if (dx == null && dy == null) return byName(x, y);
        if (dx == null) return 1;
        if (dy == null) return -1;
        final c = dx.compareTo(dy);
        return c != 0 ? c : byName(x, y);
      });
    case PeopleSort.name:
      list.sort(byName);
  }
  return list;
}

/// Görünen satırların TL toplamları.
class SummaryTotals {
  const SummaryTotals({
    required this.receivable,
    required this.payable,
    required this.pendingCount,
  });

  factory SummaryTotals.of(List<PersonRow> rows) {
    var receivable = 0;
    var payable = 0;
    var pending = 0;
    for (final r in rows) {
      if (r.balance.minor > 0) {
        receivable += r.balance.minor;
      } else {
        payable -= r.balance.minor;
      }
      pending += r.pendingCount;
    }
    return SummaryTotals(
      receivable: Money(receivable, Asset.tryLira),
      payable: Money(payable, Asset.tryLira),
      pendingCount: pending,
    );
  }

  final Money receivable;
  final Money payable;
  final int pendingCount;

  Money get net => receivable - payable;
}

/// Vade takviminde bir satır.
class DueRow {
  const DueRow({
    required this.ledger,
    required this.item,
    required this.name,
    required this.amount,
  });

  final Ledger ledger;
  final DueItem item;
  final String name;

  /// Kullanıcının gözünden (pozitif = alacağınız).
  final Money amount;

  bool get iOwe => amount.isNegative;
}

/// Tüm defterlerin açık vadeleri: gecikmiş, yaklaşan (30 gün) ve sonrası.
class DueSchedule {
  const DueSchedule({
    required this.overdue,
    required this.upcoming,
    required this.later,
  });

  static const horizonDays = 30;

  factory DueSchedule.of(List<Ledger> ledgers, String uid, LocalDate today) {
    final rows = <DueRow>[];
    for (final ledger in ledgers) {
      final me = ledger.sideOf(uid) ?? Side.a;
      final name = ledger.other(uid).displayName;
      for (final item in ledger.dueItems) {
        rows.add(
          DueRow(
            ledger: ledger,
            item: item,
            name: name,
            amount: item.signedFor(me),
          ),
        );
      }
    }
    rows.sort((x, y) {
      final c = x.item.dueOn.compareTo(y.item.dueOn);
      return c != 0 ? c : trLower(x.name).compareTo(trLower(y.name));
    });
    final horizon = today.addDays(horizonDays);
    return DueSchedule(
      overdue: [for (final r in rows) if (r.item.dueOn < today) r],
      upcoming: [
        for (final r in rows)
          if (!(r.item.dueOn < today) && !(horizon < r.item.dueOn)) r,
      ],
      later: [for (final r in rows) if (horizon < r.item.dueOn) r],
    );
  }

  final List<DueRow> overdue;
  final List<DueRow> upcoming;
  final List<DueRow> later;

  bool get isEmpty => overdue.isEmpty && upcoming.isEmpty && later.isEmpty;
}

/// "3 gün geçti", "Bugün", "Yarın", "5 gün sonra".
String relativeDue(LocalDate due, LocalDate today) {
  // UTC: yaz saati geçişinde gün farkı kaymasın.
  final days = DateTime.utc(due.year, due.month, due.day)
      .difference(DateTime.utc(today.year, today.month, today.day))
      .inDays;
  if (days == 0) return 'Bugün';
  if (days == 1) return 'Yarın';
  if (days == -1) return 'Dün';
  return days < 0 ? '${-days} gün geçti' : '$days gün sonra';
}
