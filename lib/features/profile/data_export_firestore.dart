import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'data_export.dart';

/// Dışa aktarma okumaları: hepsi sunucudan (önbellek eski olabilir).
///
/// Kurallar (firestore.rules) kayıt, sürüm ve olay listelerinde
/// `memberUids array-contains uid` süzgecini ister; her liste sorgusu bunu
/// taşır. `orderBy` kullanılmaz: tek alanlı süzgeç otomatik dizinle çalışır
/// (yeni bileşik dizin gerekmez) ve sıralama alanı eksik belge düşmez.
/// Sıralama istemcide yapılır (buildDataExport).
class FirestoreDataExportSource implements DataExportSource {
  FirestoreDataExportSource({this._firestore, this._auth});

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  // Firebase'e ilk kullanımda bağlanır.
  late final FirebaseFirestore _db = _firestore ?? FirebaseFirestore.instance;
  late final FirebaseAuth _authInstance = _auth ?? FirebaseAuth.instance;

  static const _server = GetOptions(source: Source.server);

  /// Tek okumanın en uzun süresi; bağlantı yarım kalırsa beklemede kalınmaz.
  static const timeout = Duration(seconds: 45);

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> _entries(String ledgerId) =>
      _db.collection('ledgers').doc(ledgerId).collection('entries');

  @override
  AccountInfo? currentAccount() {
    final user = _authInstance.currentUser;
    if (user == null) return null;
    return AccountInfo(
      uid: user.uid,
      email: user.email,
      emailVerified: user.emailVerified,
      displayName: user.displayName,
      phoneNumber: user.phoneNumber,
      methods: [
        for (final p in user.providerData)
          (
            providerId: p.providerId,
            uid: p.uid,
            email: p.email,
            displayName: p.displayName,
            phoneNumber: p.phoneNumber,
          ),
      ],
      createdAt: user.metadata.creationTime,
      lastSignInAt: user.metadata.lastSignInTime,
    );
  }

  @override
  Future<RawDoc?> userProfile(String uid) => _doc(_users.doc(uid)); // Kural: yalnızca sahibi.

  @override
  Future<RawDoc?> publicProfile(String uid) =>
      _doc(_db.collection('publicProfiles').doc(uid));

  @override
  Future<List<RawDoc>> ledgers(String uid) =>
      _list(_db.collection('ledgers').where('memberUids', arrayContains: uid));

  @override
  Future<List<RawDoc>> entries(String ledgerId, String uid) =>
      _list(_entries(ledgerId).where('memberUids', arrayContains: uid));

  @override
  Future<List<RawDoc>> revisions(String ledgerId, String entryId, String uid) =>
      _list(
        _entries(ledgerId)
            .doc(entryId)
            .collection('revisions')
            .where('memberUids', arrayContains: uid),
      );

  @override
  Future<List<RawDoc>> events(String ledgerId, String uid) => _list(
    _db
        .collection('ledgers')
        .doc(ledgerId)
        .collection('events')
        .where('memberUids', arrayContains: uid),
  );

  // Gelen kutusu ve bildirimler kişinin kendi altındadır (isSelf).
  @override
  Future<List<RawDoc>> inbox(String uid) =>
      _list(_users.doc(uid).collection('inbox'));

  @override
  Future<List<RawDoc>> notifications(String uid) =>
      _list(_users.doc(uid).collection('notifications'));

  Future<RawDoc?> _doc(DocumentReference<Map<String, dynamic>> ref) =>
      _guard(() async {
        final snap = await ref.get(_server);
        final data = snap.data();
        return data == null ? null : (id: snap.id, data: data);
      });

  Future<List<RawDoc>> _list(Query<Map<String, dynamic>> query) =>
      _guard(() async {
        final snap = await query.get(_server);
        return [for (final d in snap.docs) (id: d.id, data: d.data())];
      });

  /// Firestore hatasını Türkçe mesaja çevirir.
  Future<T> _guard<T>(Future<T> Function() read) async {
    try {
      return await read().timeout(timeout);
    } on TimeoutException {
      throw const DataExportException(dataExportOfflineMessage);
    } on FirebaseException catch (e) {
      throw DataExportException(dataExportErrorMessage(e.code));
    }
  }
}

/// Firestore hata kodunun kullanıcı metni.
String dataExportErrorMessage(String code) => switch (code) {
  'unavailable' ||
  'deadline-exceeded' ||
  'cancelled' => dataExportOfflineMessage,
  'permission-denied' || 'unauthenticated' =>
    'Verilerinize erişilemedi. Çıkış yapıp yeniden girin, sonra tekrar '
        'deneyin.',
  _ => 'Veriler okunamadı. Biraz sonra tekrar deneyin.',
};
