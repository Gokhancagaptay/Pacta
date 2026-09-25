import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/dates/local_date.dart';
import '../../../core/money/asset.dart';
import '../../../core/money/money.dart';

// v2 defter modelleri. Alanlar functions/src/ledger/model.ts ile aynıdır.
// Bakiye işareti defterde a tarafına göredir; ekranlar her zaman
// kullanıcının bakış açısını gösterir (pozitif = karşı taraf size borçlu).

enum Side { a, b }

enum EntryKind { debt, payment, reversal }

enum EntryState { pending, confirmed, disputed, rejected, cancelled }

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

DateTime? _time(Object? value) => value is Timestamp ? value.toDate() : null;

class LedgerSide {
  const LedgerSide({required this.uid, required this.displayName});

  factory LedgerSide.fromMap(Map<String, dynamic>? m) => LedgerSide(
    uid: m?['uid'] as String?,
    displayName: (m?['displayName'] as String?) ?? 'Pacta kullanıcısı',
  );

  final String? uid;
  final String displayName;
}

class Ledger {
  const Ledger({
    required this.id,
    required this.isPrivate,
    required this.a,
    required this.b,
    required this.balances,
    required this.pendingCount,
    this.lastEntryAt,
  });

  factory Ledger.fromMap(String id, Map<String, dynamic> m) {
    final sides = (m['sides'] as Map?)?.cast<String, dynamic>() ?? const {};
    final raw = (m['balances'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Ledger(
      id: id,
      isPrivate: m['mode'] == 'private',
      a: LedgerSide.fromMap((sides['a'] as Map?)?.cast<String, dynamic>()),
      b: LedgerSide.fromMap((sides['b'] as Map?)?.cast<String, dynamic>()),
      balances: {
        for (final e in raw.entries) e.key: (e.value as num).toInt(),
      },
      pendingCount: (m['pendingCount'] as num?)?.toInt() ?? 0,
      lastEntryAt: _time(m['lastEntryAt']),
    );
  }

  final String id;
  final bool isPrivate;
  final LedgerSide a;
  final LedgerSide b;

  /// Onaylı bakiyeler, a tarafına göre (pozitif = b, a'ya borçlu).
  final Map<String, int> balances;
  final int pendingCount;
  final DateTime? lastEntryAt;

  Side? sideOf(String uid) =>
      a.uid == uid ? Side.a : (b.uid == uid ? Side.b : null);

  LedgerSide me(String uid) => sideOf(uid) == Side.b ? b : a;
  LedgerSide other(String uid) => sideOf(uid) == Side.b ? a : b;

  /// Kullanıcının bakış açısından bakiyeler; sıfır olanlar atlanır.
  List<Money> balancesFor(String uid) {
    final sign = sideOf(uid) == Side.b ? -1 : 1;
    final list = <Money>[];
    for (final asset in Asset.values) {
      final value = balances[asset.code] ?? 0;
      if (value != 0) list.add(Money(value * sign, asset));
    }
    return list;
  }

  Money balanceFor(String uid, [Asset asset = Asset.tryLira]) {
    final sign = sideOf(uid) == Side.b ? -1 : 1;
    return Money((balances[asset.code] ?? 0) * sign, asset);
  }
}

class EntryDispute {
  const EntryDispute({
    required this.reason,
    required this.note,
    this.suggestedAmountMinor,
  });

  factory EntryDispute.fromMap(Map<String, dynamic> m) => EntryDispute(
    reason: (m['reason'] as String?) ?? 'other',
    note: (m['note'] as String?) ?? '',
    suggestedAmountMinor: (m['suggestedAmountMinor'] as num?)?.toInt(),
  );

  final String reason;
  final String note;
  final int? suggestedAmountMinor;
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.ledgerId,
    required this.kind,
    required this.aToB,
    required this.asset,
    required this.amountMinor,
    required this.deltaMinor,
    required this.occurredOn,
    required this.dueOn,
    required this.description,
    required this.linkedEntryId,
    required this.state,
    required this.version,
    required this.proposedBy,
    required this.proposedByUid,
    required this.awaitingSide,
    required this.autoConfirmed,
    required this.reversedBy,
    required this.reversalPendingId,
    required this.dispute,
    this.createdAt,
  });

  factory LedgerEntry.fromMap(String id, Map<String, dynamic> m) {
    final awaiting = m['awaitingSide'];
    final dispute = (m['dispute'] as Map?)?.cast<String, dynamic>();
    return LedgerEntry(
      id: id,
      ledgerId: (m['ledgerId'] as String?) ?? '',
      kind: _enum(EntryKind.values, m['kind'], EntryKind.debt),
      aToB: m['direction'] == 'aToB',
      asset: Asset.fromCode((m['asset'] as String?) ?? 'TRY'),
      amountMinor: (m['amountMinor'] as num?)?.toInt() ?? 0,
      deltaMinor: (m['deltaMinor'] as num?)?.toInt() ?? 0,
      occurredOn: LocalDate.parse(m['occurredOn'] as String),
      dueOn: LocalDate.tryParse(m['dueOn'] as String?),
      description: (m['description'] as String?) ?? '',
      linkedEntryId: m['linkedEntryId'] as String?,
      state: _enum(EntryState.values, m['state'], EntryState.pending),
      version: (m['version'] as num?)?.toInt() ?? 1,
      proposedBy: _enum(Side.values, m['proposedBy'], Side.a),
      proposedByUid: (m['proposedByUid'] as String?) ?? '',
      awaitingSide: awaiting == null ? null : _enum(Side.values, awaiting, Side.a),
      autoConfirmed: m['autoConfirmed'] == true,
      reversedBy: m['reversedBy'] as String?,
      reversalPendingId: m['reversalPendingId'] as String?,
      dispute: dispute == null ? null : EntryDispute.fromMap(dispute),
      createdAt: _time(m['createdAt']),
    );
  }

  final String id;
  final String ledgerId;
  final EntryKind kind;
  final bool aToB;
  final Asset asset;
  final int amountMinor;
  final int deltaMinor;
  final LocalDate occurredOn;
  final LocalDate? dueOn;
  final String description;
  final String? linkedEntryId;
  final EntryState state;
  final int version;
  final Side proposedBy;
  final String proposedByUid;
  final Side? awaitingSide;
  final bool autoConfirmed;
  final String? reversedBy;
  final String? reversalPendingId;
  final EntryDispute? dispute;
  final DateTime? createdAt;

  Money get amount => Money(amountMinor, asset);

  /// Bir tarafın bakış açısından bakiyeye etki.
  int deltaFor(Side side) => side == Side.a ? deltaMinor : -deltaMinor;

  /// Kullanıcıdan bir eylem bekleniyor mu (onay ya da düzeltme).
  bool awaits(Side side) =>
      (state == EntryState.pending || state == EntryState.disputed) &&
      awaitingSide == side;

  bool get isOpen =>
      state == EntryState.pending || state == EntryState.disputed;

  bool get canBeReversed =>
      state == EntryState.confirmed &&
      kind != EntryKind.reversal &&
      reversedBy == null &&
      reversalPendingId == null;
}

class InboxItem {
  const InboxItem({
    required this.type,
    required this.ledgerId,
    required this.entryId,
    required this.fromName,
    required this.kind,
    required this.amount,
    required this.myDeltaMinor,
    required this.description,
    required this.version,
    this.createdAt,
  });

  factory InboxItem.fromMap(Map<String, dynamic> m) => InboxItem(
    type: (m['type'] as String?) ?? 'confirmEntry',
    ledgerId: m['ledgerId'] as String,
    entryId: m['entryId'] as String,
    fromName: (m['fromName'] as String?) ?? '',
    kind: _enum(EntryKind.values, m['kind'], EntryKind.debt),
    amount: Money(
      (m['amountMinor'] as num?)?.toInt() ?? 0,
      Asset.fromCode((m['asset'] as String?) ?? 'TRY'),
    ),
    myDeltaMinor: (m['myDeltaMinor'] as num?)?.toInt() ?? 0,
    description: (m['description'] as String?) ?? '',
    version: (m['version'] as num?)?.toInt() ?? 1,
    createdAt: _time(m['createdAt']),
  );

  /// `confirmEntry`: onayınız bekleniyor; `reviseEntry`: itiraz edildi.
  final String type;
  final String ledgerId;
  final String entryId;
  final String fromName;
  final EntryKind kind;
  final Money amount;
  final int myDeltaMinor;
  final String description;
  final int version;
  final DateTime? createdAt;

  bool get needsConfirmation => type == 'confirmEntry';
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.ledgerId,
    required this.entryId,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> m) =>
      AppNotification(
        id: id,
        type: (m['type'] as String?) ?? '',
        title: (m['title'] as String?) ?? '',
        message: (m['message'] as String?) ?? '',
        ledgerId: m['ledgerId'] as String?,
        entryId: m['entryId'] as String?,
        isRead: m['isRead'] == true,
        createdAt: _time(m['createdAt']),
      );

  final String id;
  final String type;
  final String title;
  final String message;
  final String? ledgerId;
  final String? entryId;
  final bool isRead;
  final DateTime? createdAt;
}

class LedgerEvent {
  const LedgerEvent({
    required this.type,
    required this.entryId,
    required this.version,
    required this.actorUid,
    this.at,
  });

  factory LedgerEvent.fromMap(Map<String, dynamic> m) => LedgerEvent(
    type: (m['type'] as String?) ?? '',
    entryId: (m['entryId'] as String?) ?? '',
    version: (m['version'] as num?)?.toInt() ?? 1,
    actorUid: (m['actorUid'] as String?) ?? '',
    at: _time(m['at']),
  );

  final String type;
  final String entryId;
  final int version;
  final String actorUid;
  final DateTime? at;
}
