import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/asset.dart';
import '../../../core/money/money.dart';
import '../data/ledger_repository.dart';
import '../domain/models.dart';

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

final entriesProvider =
    StreamProvider.autoDispose.family<List<LedgerEntry>, String>((ref, id) {
      final uid = ref.watch(currentUidProvider);
      return ref.watch(ledgerRepositoryProvider).watchEntries(id, uid);
    });

typedef EntryKey = ({String ledgerId, String entryId});

final entryProvider = StreamProvider.autoDispose.family<LedgerEntry?, EntryKey>(
  (ref, key) => ref
      .watch(ledgerRepositoryProvider)
      .watchEntry(key.ledgerId, key.entryId),
);

final entryEventsProvider =
    StreamProvider.autoDispose.family<List<LedgerEvent>, EntryKey>((ref, key) {
      final uid = ref.watch(currentUidProvider);
      return ref
          .watch(ledgerRepositoryProvider)
          .watchEntryEvents(key.ledgerId, key.entryId, uid);
    });

final inboxProvider = StreamProvider.autoDispose<List<InboxItem>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(ledgerRepositoryProvider).watchInbox(uid);
});

final notificationsProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
      final uid = ref.watch(currentUidProvider);
      return ref.watch(ledgerRepositoryProvider).watchNotifications(uid);
    });

/// Tüm defterlerin kullanıcı bakış açısından onaylı toplamı.
class Totals {
  const Totals({
    required this.net,
    required this.receivable,
    required this.payable,
    required this.others,
  });

  /// Bir kullanıcının tüm defterlerini birim bazında toplar. TL ana karttadır,
  /// diğer birimler (altın, döviz) [others] listesinde ayrı durur.
  factory Totals.from(List<Ledger> ledgers, String uid) {
    var receivable = 0;
    var payable = 0;
    final others = <String, int>{};
    for (final ledger in ledgers) {
      for (final money in ledger.balancesFor(uid)) {
        if (money.asset == Asset.tryLira) {
          if (money.minor > 0) {
            receivable += money.minor;
          } else {
            payable -= money.minor;
          }
        } else {
          others[money.asset.code] = (others[money.asset.code] ?? 0) + money.minor;
        }
      }
    }
    return Totals(
      net: Money(receivable - payable, Asset.tryLira),
      receivable: Money(receivable, Asset.tryLira),
      payable: Money(payable, Asset.tryLira),
      others: [
        for (final e in others.entries)
          if (e.value != 0) Money(e.value, Asset.fromCode(e.key)),
      ],
    );
  }

  final Money net;
  final Money receivable;
  final Money payable;
  final List<Money> others;

  /// "Ayrıca 2 çeyrek alacağınız, 1,500 gr borcunuz var".
  String? get othersSentence {
    if (others.isEmpty) return null;
    final parts = [
      for (final m in others)
        m.isNegative
            ? '${(-m).format()} borcunuz'
            : '${m.format()} alacağınız',
    ];
    return 'Ayrıca ${parts.join(', ')} var.';
  }
}

final totalsProvider = Provider.autoDispose<AsyncValue<Totals>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(ledgersProvider).whenData((l) => Totals.from(l, uid));
});
