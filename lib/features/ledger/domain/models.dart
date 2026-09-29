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
  const LedgerSide({
    required this.uid,
    required this.displayName,
    this.email,
    this.deleted = false,
  });

  factory LedgerSide.fromMap(Map<String, dynamic>? m) => LedgerSide(
    uid: m?['uid'] as String?,
    displayName: (m?['displayName'] as String?) ?? 'Pacta kullanıcısı',
    email: m?['email'] as String?,
    deleted: m?['deleted'] == true,
  );

  final String? uid;
  final String displayName;

  /// Ortak defterde giriş e-postası (özel defterde yok).
  final String? email;

  /// Bu kişi hesabını sildi (ad anonim, defter kapalı).
  final bool deleted;
}

/// Vadesi olan, henüz kapanmamış borç parçası. Sunucu hesaplar: ödemeler
/// önce en eski borcu kapatır (functions/src/ledger/due.ts).
class DueItem {
  const DueItem({
    required this.entryId,
    required this.debtorSide,
    required this.open,
    required this.dueOn,
    required this.description,
  });

  factory DueItem.fromMap(Map<String, dynamic> m) => DueItem(
    entryId: m['entryId'] as String,
    debtorSide: _enum(Side.values, m['debtorSide'], Side.b),
    open: Money(
      (m['openMinor'] as num?)?.toInt() ?? 0,
      Asset.fromCode((m['asset'] as String?) ?? 'TRY'),
    ),
    dueOn: LocalDate.parse(m['dueOn'] as String),
    description: (m['description'] as String?) ?? '',
  );

  final String entryId;
  final Side debtorSide;
  final Money open;
  final LocalDate dueOn;
  final String description;

  /// Kullanıcının bakış açısından tutar: pozitif = karşı taraf size borçlu.
  Money signedFor(Side me) => debtorSide == me ? -open : open;
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
    this.dueItems = const [],
    this.lastReminderOn = const {},
    this.isClosed = false,
    this.convertedTo,
    this.chainSeq = 0,
    this.chainHash = '',
    this.blockedBy = const {},
  });

  factory Ledger.fromMap(String id, Map<String, dynamic> m) {
    final blocked = (m['blockedBy'] as Map?) ?? const {};
    final sides = (m['sides'] as Map?)?.cast<String, dynamic>() ?? const {};
    final raw = (m['balances'] as Map?)?.cast<String, dynamic>() ?? const {};
    final reminders =
        (m['reminders'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Ledger(
      id: id,
      isPrivate: m['mode'] == 'private',
      isClosed: m['status'] == 'closed',
      convertedTo: m['convertedTo'] as String?,
      chainSeq: ((m['head'] as Map?)?['seq'] as num?)?.toInt() ?? 0,
      chainHash: ((m['head'] as Map?)?['chainHash'] as String?) ?? '',
      blockedBy: {
        for (final side in Side.values)
          if (blocked[side.name] == true) side,
      },
      a: LedgerSide.fromMap((sides['a'] as Map?)?.cast<String, dynamic>()),
      b: LedgerSide.fromMap((sides['b'] as Map?)?.cast<String, dynamic>()),
      balances: {for (final e in raw.entries) e.key: (e.value as num).toInt()},
      pendingCount: (m['pendingCount'] as num?)?.toInt() ?? 0,
      lastEntryAt: _time(m['lastEntryAt']),
      dueItems: [
        for (final item in (m['dueItems'] as List?) ?? const [])
          DueItem.fromMap((item as Map).cast<String, dynamic>()),
      ],
      lastReminderOn: {
        for (final side in Side.values)
          if (LocalDate.tryParse(
                (reminders[side.name] as Map?)?['lastOn'] as String?,
              )
              case final day?)
            side: day,
      },
    );
  }

  final String id;
  final bool isPrivate;

  /// Taraflardan biri hesabını sildi ya da özel defter ortak deftere
  /// taşındı: geçmiş okunur, yeni kayıt eklenemez.
  final bool isClosed;

  /// Özel defter bu ortak deftere taşındı (bkz. [isArchived]).
  final String? convertedTo;

  /// Ortak deftere taşınmış özel defter: yalnızca arşivde görünür; listelere
  /// ve toplamlara girmez (bakiye artık ortak defterde).
  bool get isArchived => convertedTo != null;

  /// Onaylı kayıt zincirinin başı: kaç onay işlendi ve son özet. Ekstrede
  /// yazılır; sonradan araya kayıt sokulmadığı buradan doğrulanır.
  final int chainSeq;
  final String chainHash;
  final LedgerSide a;
  final LedgerSide b;

  /// Onaylı bakiyeler, a tarafına göre (pozitif = b, a'ya borçlu).
  final Map<String, int> balances;
  final int pendingCount;
  final DateTime? lastEntryAt;

  /// Açık vadeler, vadeye göre sıralı.
  final List<DueItem> dueItems;

  /// Tarafın karşı tarafa en son hatırlatma gönderdiği gün.
  final Map<Side, LocalDate> lastReminderOn;

  /// Karşı tarafını engelleyen taraflar (engellenen kayıt ve hatırlatma
  /// gönderemez; sunucu uygular).
  final Set<Side> blockedBy;

  /// Kullanıcı karşı tarafı engelledi mi.
  bool blockedByMe(String uid) => blockedBy.contains(sideOf(uid));

  /// Karşı taraf kullanıcıyı engelledi mi.
  bool blocksMe(String uid) {
    final me = sideOf(uid);
    return me != null && blockedBy.contains(me == Side.a ? Side.b : Side.a);
  }

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

/// Uygulaması olmayan karşı tarafın web'deki yanıtı (yalnızca özel
/// defterde). Özel defterin bakiyesini değiştirmez; kayda kanıt olarak
/// eklenir (functions/src/ledger/web.ts).
enum WebConfirmationState { requested, confirmed, disputed, rejected }

class WebConfirmation {
  const WebConfirmation({
    required this.state,
    this.emailMasked,
    this.reason,
    this.note = '',
    this.suggestedAmountMinor,
    this.requestedAt,
    this.respondedAt,
    this.expiresAt,
  });

  factory WebConfirmation.fromMap(Map<String, dynamic> m) => WebConfirmation(
    state: _enum(
      WebConfirmationState.values,
      m['state'],
      WebConfirmationState.requested,
    ),
    emailMasked: m['emailMasked'] as String?,
    reason: m['reason'] as String?,
    note: (m['note'] as String?) ?? '',
    suggestedAmountMinor: (m['suggestedAmountMinor'] as num?)?.toInt(),
    requestedAt: _time(m['requestedAt']),
    respondedAt: _time(m['respondedAt']),
    expiresAt: _time(m['expiresAt']),
  );

  final WebConfirmationState state;

  /// Yanıtlayanın gizlenmiş e-postası: "a***@gmail.com".
  final String? emailMasked;

  /// İtiraz ya da ret gerekçesi (EntryText sözlüklerindeki anahtarlar).
  final String? reason;
  final String note;
  final int? suggestedAmountMinor;
  final DateTime? requestedAt;
  final DateTime? respondedAt;

  /// Link bu andan sonra yanıt kabul etmez.
  final DateTime? expiresAt;

  /// Link gönderildi ama yanıt gelmeden süresi doldu.
  bool isExpired(DateTime now) =>
      state == WebConfirmationState.requested &&
      expiresAt != null &&
      !now.isBefore(expiresAt!);
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
    this.rejectionReason,
    this.webConfirmation,
    this.createdAt,
    this.updatedAt,
  });

  factory LedgerEntry.fromMap(String id, Map<String, dynamic> m) {
    final awaiting = m['awaitingSide'];
    final dispute = (m['dispute'] as Map?)?.cast<String, dynamic>();
    final web = (m['webConfirmation'] as Map?)?.cast<String, dynamic>();
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
      awaitingSide: awaiting == null
          ? null
          : _enum(Side.values, awaiting, Side.a),
      autoConfirmed: m['autoConfirmed'] == true,
      reversedBy: m['reversedBy'] as String?,
      reversalPendingId: m['reversalPendingId'] as String?,
      dispute: dispute == null ? null : EntryDispute.fromMap(dispute),
      rejectionReason: (m['rejection'] as Map?)?['reason'] as String?,
      webConfirmation: web == null ? null : WebConfirmation.fromMap(web),
      createdAt: _time(m['createdAt']),
      updatedAt: _time(m['updatedAt']),
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

  /// Ret gerekçesi (ör. "accountDeleted": karşı taraf hesabını sildi).
  final String? rejectionReason;

  /// Özel defterde karşı tarafın web'den verdiği yanıt.
  final WebConfirmation? webConfirmation;
  final DateTime? createdAt;

  /// Son durum değişikliği (Hareketler > Geçmiş sırası).
  final DateTime? updatedAt;

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

  /// Özel defterde karşı taraftan web onayı istenebilir mi (sunucuyla aynı
  /// koşullar; defterin özel ve açık olduğunu çağıran bilir).
  bool get canRequestWebConfirmation =>
      state == EntryState.confirmed &&
      kind != EntryKind.reversal &&
      reversedBy == null &&
      webConfirmation?.state != WebConfirmationState.confirmed;
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
    this.reason,
    this.at,
  });

  factory LedgerEvent.fromMap(Map<String, dynamic> m) => LedgerEvent(
    type: (m['type'] as String?) ?? '',
    entryId: (m['entryId'] as String?) ?? '',
    version: (m['version'] as num?)?.toInt() ?? 1,
    actorUid: (m['actorUid'] as String?) ?? '',
    reason: m['reason'] as String?,
    at: _time(m['at']),
  );

  final String type;
  final String entryId;
  final int version;
  final String actorUid;

  /// Olayın nedeni (ör. "accountDeleted": kişi hesabını sildiği için).
  final String? reason;
  final DateTime? at;
}
