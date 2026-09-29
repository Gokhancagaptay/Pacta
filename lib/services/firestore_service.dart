// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:pacta/models/user_model.dart';

/// Kullanıcı profili (users/{uid}) ve herkese açık adı (publicProfiles/{uid}).
///
/// Defter verisi LedgerRepository'dedir; bu servis yalnızca profil içindir.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final CollectionReference<UserModel> usersRef = _db
      .collection(_usersCollection)
      .withConverter<UserModel>(
        // Kimlik belgeden gelir: "uid" alanı olmayan eski profillerde
        // kaydetme sessizce boşa gitmesin.
        fromFirestore: (snapshot, _) =>
            UserModel.fromMap({...snapshot.data()!, 'uid': snapshot.id}),
        toFirestore: (user, _) => user.toMap(),
      );

  static const String _usersCollection = AppConstants.usersCollection;
  static const String _publicProfilesCollection =
      AppConstants.publicProfilesCollection;

  /// `users/{uid}` yalnızca sahibine açıktır; diğer kullanıcıların görebileceği
  /// tek bilgi olan ad soyad `publicProfiles/{uid}` altında tutulur.
  Future<void> syncPublicProfile(String uid, String? adSoyad) async {
    if (uid.isEmpty) return;
    await _db.collection(_publicProfilesCollection).doc(uid).set({
      'adSoyad': (adSoyad ?? '').trim(),
    });
  }

  /// Kullanım Koşulları'nın güncel sürümünün kabul edildiğini kaydeder
  /// (zaman sunucudan; kurallar başka zamanı kabul etmez).
  static Map<String, dynamic> termsAcceptance() => {
    'termsVersion': AppConstants.termsVersion,
    'termsAcceptedAt': FieldValue.serverTimestamp(),
  };

  Future<void> acceptTerms(String uid) => _db
      .collection(_usersCollection)
      .doc(uid)
      .set(termsAcceptance(), SetOptions(merge: true));

  /// Profili oluşturur ya da eksik alanlarını tamamlar. Belgenin var olup
  /// olmamasına bakmaz: bildirim anahtarı belgeyi profilden önce
  /// oluşturmuş olabilir. Var olan alanlar (ad, ayarlar) ezilmez.
  /// [acceptedTerms]: kayıt formunda koşullar az önce kabul edildi.
  Future<void> ensureProfile({
    required String uid,
    required String email,
    String? adSoyad,
    String? telefon,
    bool acceptedTerms = false,
  }) async {
    final ref = _db.collection(_usersCollection).doc(uid);
    final data = (await ref.get()).data() ?? const <String, dynamic>{};
    final currentName = (data['adSoyad'] as String?)?.trim() ?? '';
    var name = currentName.isNotEmpty ? currentName : (adSoyad ?? '').trim();
    if (name.length > 100) name = name.substring(0, 100);

    final update = <String, dynamic>{
      if (data['uid'] == null) 'uid': uid,
      if (data['email'] == null && email.isNotEmpty) 'email': email,
      if (currentName.isEmpty && name.isNotEmpty) 'adSoyad': name,
      if (data['telefon'] == null && (telefon ?? '').trim().isNotEmpty)
        'telefon': telefon!.trim(),
      if (data['notificationSettings'] == null)
        'notificationSettings': NotificationSettings().toMap(),
      if (acceptedTerms) ...termsAcceptance(),
    };
    if (update.isNotEmpty) await ref.set(update, SetOptions(merge: true));

    final public = await _db
        .collection(_publicProfilesCollection)
        .doc(uid)
        .get();
    if (!public.exists || (public.data()?['adSoyad'] ?? '') != name) {
      await syncPublicProfile(uid, name);
    }
  }

  Stream<UserModel?> getUserStream(String uid) {
    return usersRef.doc(uid).snapshots().map((snapshot) => snapshot.data());
  }

  /// Profil alanlarını günceller; ad değiştiyse herkese açık ad da güncellenir.
  /// Ad değişikliği profil ve herkese açık adla birlikte tek yazımdır.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    if (uid.isEmpty || data.isEmpty) return;
    final batch = _db.batch();
    batch.update(_db.collection(_usersCollection).doc(uid), data);
    if (data.containsKey('adSoyad')) {
      batch.set(_db.collection(_publicProfilesCollection).doc(uid), {
        'adSoyad': ((data['adSoyad'] as String?) ?? '').trim(),
      });
    }
    await batch.commit();
  }
}
