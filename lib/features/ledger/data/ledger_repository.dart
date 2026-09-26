import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../constants/app_constants.dart';
import '../../../core/dates/local_date.dart';
import '../../../core/money/money.dart';
import '../domain/models.dart';
import '../domain/reminder.dart';

/// Komut hatası; mesaj sunucudan Türkçe gelir.
class LedgerException implements Exception {
  const LedgerException(this.message, {this.isStale = false});

  final String message;

  /// Kullanıcı eski bir sürüme bakıyordu; ekran güncel hâli gösterecek.
  final bool isStale;

  @override
  String toString() => message;
}

/// Eklenen kişi: açılan (ya da zaten olan) defter.
class AddedPerson {
  const AddedPerson({
    required this.ledgerId,
    required this.name,
    required this.created,
  });

  factory AddedPerson.fromMap(Map<String, dynamic> m) => AddedPerson(
    ledgerId: m['ledgerId'] as String,
    name: (m['displayName'] as String?) ?? 'Kişi',
    created: m['created'] == true,
  );

  final String ledgerId;
  final String name;
  final bool created;
}

/// v2 defter verisi. Okumalar Firestore akışı, tüm yazmalar Cloud Functions
/// komutudur (istemci ledgers altına yazamaz, bkz. firestore.rules).
class LedgerRepository {
  LedgerRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore,
      _functions = functions;

  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  // Firebase'e ilk kullanımda bağlanır; testlerde sahte depo Firebase'siz çalışır.
  late final FirebaseFirestore _db = _firestore ?? FirebaseFirestore.instance;
  late final FirebaseFunctions _fn =
      _functions ??
      FirebaseFunctions.instanceFor(region: AppConstants.functionsRegion);

  CollectionReference<Map<String, dynamic>> get _ledgers =>
      _db.collection('ledgers');

  /// Yeni kayıt kimliği; aynı kimlikle tekrar gönderim tek kayıt üretir.
  String newId() => _ledgers.doc().id;

  // --- Okuma -------------------------------------------------------------

  Stream<List<Ledger>> watchLedgers(String uid) => _ledgers
      .where('memberUids', arrayContains: uid)
      .orderBy('lastEntryAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) Ledger.fromMap(d.id, d.data())]);

  Stream<Ledger?> watchLedger(String ledgerId) => _ledgers
      .doc(ledgerId)
      .snapshots()
      .map((d) => d.exists ? Ledger.fromMap(d.id, d.data()!) : null);

  Stream<List<LedgerEntry>> watchEntries(String ledgerId, String uid) =>
      _ledgers
          .doc(ledgerId)
          .collection('entries')
          .where('memberUids', arrayContains: uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (s) => [
              for (final d in s.docs) LedgerEntry.fromMap(d.id, d.data()),
            ],
          );

  /// Tüm defterlerdeki kayıtlar, son değişene göre (Hareketler > Geçmiş).
  Stream<List<LedgerEntry>> watchRecentEntries(String uid, {int limit = 40}) =>
      _db
          .collectionGroup('entries')
          .where('memberUids', arrayContains: uid)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (s) => [
              for (final d in s.docs) LedgerEntry.fromMap(d.id, d.data()),
            ],
          );

  Stream<LedgerEntry?> watchEntry(String ledgerId, String entryId) => _ledgers
      .doc(ledgerId)
      .collection('entries')
      .doc(entryId)
      .snapshots()
      .map((d) => d.exists ? LedgerEntry.fromMap(d.id, d.data()!) : null);

  Stream<List<LedgerEvent>> watchEntryEvents(
    String ledgerId,
    String entryId,
    String uid,
  ) => _ledgers
      .doc(ledgerId)
      .collection('events')
      .where('memberUids', arrayContains: uid)
      .where('entryId', isEqualTo: entryId)
      .snapshots()
      .map((s) {
        final events = [for (final d in s.docs) LedgerEvent.fromMap(d.data())];
        events.sort(
          (x, y) => (x.at ?? DateTime.now()).compareTo(y.at ?? DateTime.now()),
        );
        return events;
      });

  Stream<List<InboxItem>> watchInbox(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('inbox')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) InboxItem.fromMap(d.data())]);

  Stream<List<AppNotification>> watchNotifications(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) AppNotification.fromMap(d.id, d.data())],
      );

  Future<void> markNotificationRead(String uid, String notificationId) => _db
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .doc(notificationId)
      .update({'isRead': true});

  /// Bu kişinin hatırlatmaları push olarak gelmez; bildirim listesinde kalır.
  Future<void> setReminderMuted(String uid, String ledgerId, bool muted) => _db
      .collection('users')
      .doc(uid)
      .set({
        'reminderMutes': {ledgerId: muted ? true : FieldValue.delete()},
      }, SetOptions(merge: true));

  // --- Komutlar ----------------------------------------------------------

  Future<String> openSharedLedger(String counterpartyUid) async {
    final r = await _call('createLedger', {'counterpartyUid': counterpartyUid});
    return r['ledgerId'] as String;
  }

  /// E-postası doğrulanmış kişiyle ortak defter. Bulunamazsa sunucu nedenini
  /// söyler (kayıtlı değil, doğrulanmamış...).
  Future<AddedPerson> addByEmail(String email) async => AddedPerson.fromMap(
    await _call('createLedger', {'counterpartyEmail': email.trim()}),
  );

  /// Pacta koduyla (elle, QR ya da davet linkinden) ortak defter.
  Future<AddedPerson> addByCode(String code) async => AddedPerson.fromMap(
    await _call('createLedger', {'counterpartyCode': code.trim()}),
  );

  /// Kodun sahibinin adı; eklemeden önce onay için.
  Future<({bool self, String name})> previewCode(String code) async {
    final r = await _call('previewCode', {'code': code.trim()});
    return (self: r['self'] == true, name: r['displayName'] as String);
  }

  /// Kullanıcının Pacta kodu; yoksa sunucu üretir.
  Future<String> myPactaCode() async =>
      (await _call('myPactaCode', {}))['code'] as String;

  Future<String> openPrivateLedger(String name) async {
    final r = await _call('createLedger', {'privateName': name});
    return r['ledgerId'] as String;
  }

  /// Özel defteri kayıtlarıyla birlikte siler (ortak defter silinmez).
  Future<void> deletePrivateLedger(String ledgerId) =>
      _call('deletePrivateLedger', {'ledgerId': ledgerId});

  Future<void> setFavorite(String uid, String ledgerId, bool favorite) =>
      _setPref(uid, 'favoriteLedgers', ledgerId, favorite ? true : null);

  /// Listeden kaldırır; defter silinmez, yeni hareket olursa geri gelir.
  Future<void> setHidden(String uid, String ledgerId, bool hidden) => _setPref(
    uid,
    'hiddenLedgers',
    ledgerId,
    hidden ? FieldValue.serverTimestamp() : null,
  );

  Future<void> _setPref(String uid, String field, String key, Object? value) =>
      _db.collection('users').doc(uid).set({
        field: {key: value ?? FieldValue.delete()},
      }, SetOptions(merge: true));

  /// [iGave]: değer sizden çıktı mı (borç verdim / ödeme yaptım).
  Future<EntryState> createEntry({
    required String ledgerId,
    required String entryId,
    required EntryKind kind,
    required bool iGave,
    required Money amount,
    required LocalDate occurredOn,
    LocalDate? dueOn,
    String description = '',
    String? linkedEntryId,
  }) async {
    final r = await _call('createEntry', {
      'ledgerId': ledgerId,
      'entryId': entryId,
      'kind': kind.name,
      'iGave': iGave,
      'asset': amount.asset.code,
      'amountMinor': amount.minor,
      'occurredOn': occurredOn.toIso(),
      'dueOn': dueOn?.toIso(),
      'description': description,
      'linkedEntryId': linkedEntryId,
    });
    return EntryState.values.byName(r['state'] as String);
  }

  Future<void> confirm(LedgerEntry e) => _call('confirmEntry', _key(e));

  /// Gelen kutusundan onay: kullanıcının gördüğü sürümle.
  Future<void> confirmById(String ledgerId, String entryId, int version) =>
      _call('confirmEntry', {
        'ledgerId': ledgerId,
        'entryId': entryId,
        'expectedVersion': version,
      });

  Future<void> dispute(
    LedgerEntry e, {
    required String reason,
    String note = '',
    Money? suggested,
  }) => _call('disputeEntry', {
    ..._key(e),
    'reason': reason,
    'note': note,
    'suggestedAmountMinor': suggested?.minor,
  });

  Future<void> reject(LedgerEntry e, {required String reason, String note = ''}) =>
      _call('rejectEntry', {..._key(e), 'reason': reason, 'note': note});

  Future<void> revise(
    LedgerEntry e, {
    Money? amount,
    LocalDate? occurredOn,
    LocalDate? dueOn,
    bool clearDue = false,
    String? description,
  }) => _call('reviseEntry', {
    ..._key(e),
    if (amount != null) 'amountMinor': amount.minor,
    if (amount != null) 'asset': amount.asset.code,
    if (occurredOn != null) 'occurredOn': occurredOn.toIso(),
    if (dueOn != null || clearDue) 'dueOn': dueOn?.toIso(),
    'description': ?description,
  });

  Future<void> cancel(LedgerEntry e) => _call('cancelEntry', _key(e));

  Future<void> reverse(LedgerEntry e, {String note = ''}) => _call(
    'reverseEntry',
    {
      'ledgerId': e.ledgerId,
      'entryId': e.id,
      'reversalId': newId(),
      'note': note,
    },
  );

  /// Karşı tarafa nazik bir uygulama içi hatırlatma; metni sunucu seçer.
  Future<ReminderResult> sendReminder(String ledgerId) async {
    final r = await _call('sendReminder', {'ledgerId': ledgerId});
    return ReminderResult(
      kind: ReminderKind.values.byName(r['kind'] as String),
      queued: r['queued'] == true,
      nextOn: LocalDate.parse(r['nextOn'] as String),
    );
  }

  Map<String, Object?> _key(LedgerEntry e) => {
    'ledgerId': e.ledgerId,
    'entryId': e.id,
    'expectedVersion': e.version,
  };

  Future<Map<String, dynamic>> _call(String name, Map<String, Object?> data) async {
    try {
      final result = await _fn.httpsCallable(name).call(data);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      final message = e.message ?? 'İşlem tamamlanamadı.';
      throw LedgerException(
        message.replaceFirst('STALE_VERSION: ', ''),
        isStale: message.startsWith('STALE_VERSION'),
      );
    } catch (_) {
      throw const LedgerException(
        'Bağlantı kurulamadı. İnternetinizi kontrol edip tekrar deneyin.',
      );
    }
  }
}
