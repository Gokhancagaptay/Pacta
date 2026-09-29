import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates/local_date.dart';
import '../../../core/money/asset.dart';
import '../../../core/money/money.dart';
import '../../profile/profile_providers.dart';
import '../data/ledger_repository.dart';
import '../domain/models.dart';
import '../domain/summary.dart';

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => LedgerRepository(),
);

final authUserProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Oturumdaki kullanıcı; değişince tüm akışlar yeniden kurulur.
final currentUidProvider = Provider<String>(
  (ref) =>
      ref.watch(authUserProvider).valueOrNull?.uid ??
      FirebaseAuth.instance.currentUser?.uid ??
      '',
);

final ledgersProvider = StreamProvider.autoDispose<List<Ledger>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(ledgerRepositoryProvider).watchLedgers(uid);
});

final ledgerProvider = StreamProvider.autoDispose.family<Ledger?, String>(
  (ref, id) => ref.watch(ledgerRepositoryProvider).watchLedger(id),
);

final entriesProvider = StreamProvider.autoDispose
    .family<List<LedgerEntry>, String>((ref, id) {
      final uid = ref.watch(currentUidProvider);
      return ref.watch(ledgerRepositoryProvider).watchEntries(id, uid);
    });

typedef EntryKey = ({String ledgerId, String entryId});

final entryProvider = StreamProvider.autoDispose.family<LedgerEntry?, EntryKey>(
  (ref, key) =>
      ref.watch(ledgerRepositoryProvider).watchEntry(key.ledgerId, key.entryId),
);

final entryEventsProvider = StreamProvider.autoDispose
    .family<List<LedgerEvent>, EntryKey>((ref, key) {
      final uid = ref.watch(currentUidProvider);
      return ref
          .watch(ledgerRepositoryProvider)
          .watchEntryEvents(key.ledgerId, key.entryId, uid);
    });

final inboxProvider = StreamProvider.autoDispose<List<InboxItem>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(ledgerRepositoryProvider).watchInbox(uid);
});

final notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>(
  (ref) {
    final uid = ref.watch(currentUidProvider);
    return ref.watch(ledgerRepositoryProvider).watchNotifications(uid);
  },
);

/// Kullanıcının bakış açısından toplamlar.
class Totals {
  const Totals({
    required this.net,
    required this.receivable,
    required this.payable,
    required this.others,
    this.private = const [],
  });

  /// "Onaylı bakiye" yalnızca açık ortak defterlerden gelir: iki tarafın
  /// onayladığı kayıtlar. TL ana karttadır, diğer birimler [others]
  /// listesinde durur. Özel defterler (karşı taraf onaylamadı) [private]
  /// listesinde ayrıca gösterilir. Kapalı defterler sayılmaz: taşınmış özel
  /// defterin bakiyesi ortak deftere geçti; karşı tarafı hesabını silmiş
  /// defter artık kapatılamaz.
  factory Totals.from(List<Ledger> ledgers, String uid) {
    var receivable = 0;
    var payable = 0;
    final others = <String, int>{};
    final private = <String, int>{};
    for (final ledger in ledgers) {
      if (ledger.isClosed) continue;
      if (ledger.isPrivate) {
        for (final money in ledger.balancesFor(uid)) {
          private[money.asset.code] =
              (private[money.asset.code] ?? 0) + money.minor;
        }
        continue;
      }
      for (final money in ledger.balancesFor(uid)) {
        if (money.asset == Asset.tryLira) {
          if (money.minor > 0) {
            receivable += money.minor;
          } else {
            payable -= money.minor;
          }
        } else {
          others[money.asset.code] =
              (others[money.asset.code] ?? 0) + money.minor;
        }
      }
    }
    return Totals(
      net: Money(receivable - payable, Asset.tryLira),
      receivable: Money(receivable, Asset.tryLira),
      payable: Money(payable, Asset.tryLira),
      others: _nonZero(others),
      private: _nonZero(private),
    );
  }

  static List<Money> _nonZero(Map<String, int> byCode) => [
    for (final e in byCode.entries)
      if (e.value != 0) Money(e.value, Asset.fromCode(e.key)),
  ];

  final Money net;
  final Money receivable;
  final Money payable;
  final List<Money> others;

  /// Özel defterlerin toplamı, birim başına (onaylı sayılmaz).
  final List<Money> private;

  /// "Ayrıca 2 çeyrek alacağınız, 1,500 gr borcunuz var".
  String? get othersSentence {
    if (others.isEmpty) return null;
    final parts = [
      for (final m in others)
        m.isNegative ? '${(-m).format()} borcunuz' : '${m.format()} alacağınız',
    ];
    return 'Ayrıca ${parts.join(', ')} var.';
  }

  /// "Özel defterlerinizde ayrıca 800,00 ₺ alacağınız var (onaysız)."
  String? get privateSentence {
    if (private.isEmpty) return null;
    final parts = [
      for (final m in private)
        m.isNegative ? '${(-m).format()} borcunuz' : '${m.format()} alacağınız',
    ];
    return 'Özel defterlerinizde ayrıca ${parts.join(', ')} var '
        '(karşı taraf onaylamadı).';
  }

  /// Karttaki dipnot: diğer birimler ve özel defterler.
  String? get footnote {
    final lines = [?othersSentence, ?privateSentence];
    return lines.isEmpty ? null : lines.join('\n');
  }
}

final totalsProvider = Provider.autoDispose<AsyncValue<Totals>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(ledgersProvider).whenData((l) => Totals.from(l, uid));
});

/// Bugün. Ana kabuk gece yarısında ve uygulamaya dönüldüğünde günceller
/// (vade renkleri, "Bugün/Dün" etiketleri eski günde kalmasın).
final todayProvider = StateProvider<LocalDate>((ref) => LocalDate.today());

/// Tüm defterlerdeki son kayıtlar (Hareketler > Geçmiş).
final recentEntriesProvider = StreamProvider.autoDispose<List<LedgerEntry>>((
  ref,
) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(ledgerRepositoryProvider).watchRecentEntries(uid);
});

/// Açık vadeler: gecikmiş, 30 gün içinde, sonrası.
final dueScheduleProvider = Provider.autoDispose<AsyncValue<DueSchedule>>((
  ref,
) {
  final uid = ref.watch(currentUidProvider);
  final today = ref.watch(todayProvider);
  return ref
      .watch(ledgersProvider)
      .whenData((l) => DueSchedule.of(l, uid, today));
});

/// Favori defterler (kullanıcı profilinden).
final favoriteLedgersProvider = Provider.autoDispose<Set<String>>(
  (ref) =>
      ref.watch(userProfileProvider).valueOrNull?.favoriteLedgers ?? const {},
);

final _hiddenMapProvider = Provider.autoDispose<Map<String, DateTime>>(
  (ref) =>
      ref.watch(userProfileProvider).valueOrNull?.hiddenLedgers ?? const {},
);

/// Listelerde görünen defterler: kaldırılanlar çıkar, favoriler başta.
/// Bakiye toplamları kaldırılanları da kapsar ([totalsProvider]).
final visibleLedgersProvider = Provider.autoDispose<AsyncValue<List<Ledger>>>((
  ref,
) {
  final favorites = ref.watch(favoriteLedgersProvider);
  final hidden = ref.watch(_hiddenMapProvider);
  return ref
      .watch(ledgersProvider)
      .whenData((l) => visibleLedgers(l, favorites: favorites, hidden: hidden));
});

/// Listeden kaldırılmış defterler (geri getirmek için).
final hiddenLedgersProvider = Provider.autoDispose<List<Ledger>>((ref) {
  final hidden = ref.watch(_hiddenMapProvider);
  final all = ref.watch(ledgersProvider).valueOrNull ?? const <Ledger>[];
  return [
    for (final l in all)
      if (!l.isArchived && isHiddenLedger(l, hidden)) l,
  ];
});

/// Bu ortak deftere taşınmış özel defterler (eski kayıtlar sahibinde kalır).
final archivedLedgersProvider = Provider.autoDispose
    .family<List<Ledger>, String>(
      (ref, sharedLedgerId) => [
        for (final l in ref.watch(ledgersProvider).valueOrNull ?? const [])
          if (l.convertedTo == sharedLedgerId) l,
      ],
    );

/// Kişi tablosunun satırları (süzülmemiş, kaldırılanlar hariç).
final personRowsProvider = Provider.autoDispose<AsyncValue<List<PersonRow>>>((
  ref,
) {
  final uid = ref.watch(currentUidProvider);
  final today = ref.watch(todayProvider);
  final favorites = ref.watch(favoriteLedgersProvider);
  return ref
      .watch(visibleLedgersProvider)
      .whenData(
        (l) => [
          for (final x in l)
            PersonRow.of(x, uid, today, favorite: favorites.contains(x.id)),
        ],
      );
});

// Süzgeç, sıralama ve arama hesaba özeldir: başka hesap girince sıfırlanır.
final peopleFilterProvider = StateProvider<PeopleFilter>((ref) {
  ref.watch(currentUidProvider);
  return PeopleFilter.all;
});
final peopleSortProvider = StateProvider<PeopleSort>((ref) {
  ref.watch(currentUidProvider);
  return PeopleSort.recent;
});
final peopleQueryProvider = StateProvider<String>((ref) {
  ref.watch(currentUidProvider);
  return '';
});

/// Bu sayıdan fazla kişi varsa Kişiler ekranında arama kutusu görünür.
const peopleSearchThreshold = 6;

/// Kişiler ekranında görünen satırlar (süzgeç, sıralama, arama uygulanmış)
/// ve toplamları; ekran ve dışa aktarma aynı listeyi kullanır.
final selectedPersonRowsProvider =
    Provider.autoDispose<
      AsyncValue<({List<PersonRow> rows, SummaryTotals totals})>
    >((ref) {
      final filter = ref.watch(peopleFilterProvider);
      final sort = ref.watch(peopleSortProvider);
      final query = ref.watch(peopleQueryProvider);
      return ref.watch(personRowsProvider).whenData((all) {
        final rows = selectRows(
          all,
          filter: filter,
          sort: sort,
          // Arama kutusu görünmüyorsa eski sorgu listeyi süzmez.
          query: all.length >= peopleSearchThreshold ? query : '',
        );
        return (rows: rows, totals: SummaryTotals.of(rows));
      });
    });

/// Kişiler ekranı tablo görünümünde mi.
/// Hesap değişince sıfırlanır (diğer kişiler ayarları gibi).
final peopleTableViewProvider = StateProvider<bool>((ref) {
  ref.watch(currentUidProvider);
  return false;
});
