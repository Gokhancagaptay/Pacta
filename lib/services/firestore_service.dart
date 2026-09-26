// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:pacta/models/debt_model.dart';
import 'package:pacta/models/saved_contact_model.dart';
import 'package:pacta/models/user_model.dart';

/// Firestore veritabanı işlemleri için servis sınıfı
///
/// Bu sınıf kullanıcı, borç ve bildirim verilerinin
/// Firestore veritabanında CRUD işlemlerini yönetir.
///
/// Ayrıca performans için user name cache'i ve
/// consistent error handling sağlar.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: AppConstants.functionsRegion,
  );
  late final CollectionReference<UserModel> usersRef;
  late final CollectionReference<DebtModel> debtsRef;

  // Use constants from AppConstants
  static const String _usersCollection = AppConstants.usersCollection;
  static const String _publicProfilesCollection =
      AppConstants.publicProfilesCollection;
  static const String _debtsCollection = AppConstants.debtsCollection;
  static const String _notificationsCollection =
      AppConstants.notificationsCollection;
  static const String _savedContactsCollection =
      AppConstants.savedContactsCollection;

  // Status constants from AppConstants
  static const String statusApproved = AppConstants.statusApproved;
  static const String statusPending = AppConstants.statusPending;
  static const String statusRejected = AppConstants.statusRejected;
  static const String statusNote = AppConstants.statusNote;
  static const String statusPendingDeletion =
      AppConstants.statusPendingDeletion;

  // Cache for user names to reduce database calls
  static final Map<String, String> _userNameCache = <String, String>{};

  FirestoreService() {
    usersRef = _db
        .collection(_usersCollection)
        .withConverter<UserModel>(
          fromFirestore: (snapshot, _) => UserModel.fromMap(snapshot.data()!),
          toFirestore: (user, _) => user.toMap(),
        );

    debtsRef = _db
        .collection(_debtsCollection)
        .withConverter<DebtModel>(
          fromFirestore: (snapshot, options) =>
              DebtModel.fromMap(snapshot.data()!, snapshot.id),
          toFirestore: (debt, _) => debt.toMap(),
        );
  }

  // USER METHODS
  Future<void> createUser(UserModel user) async {
    await usersRef.doc(user.uid).set(user);
    await syncPublicProfile(user.uid, user.adSoyad);
  }

  /// `users/{uid}` yalnızca sahibine açıktır; diğer kullanıcıların görebileceği
  /// tek bilgi olan ad soyad `publicProfiles/{uid}` altında tutulur.
  Future<void> syncPublicProfile(String uid, String? adSoyad) async {
    if (uid.isEmpty) return;
    await _db.collection(_publicProfilesCollection).doc(uid).set({
      'adSoyad': (adSoyad ?? '').trim(),
    });
  }

  /// Profili oluşturur ya da eksik alanlarını tamamlar. Belgenin var olup
  /// olmamasına bakmaz: bildirim anahtarı belgeyi profilden önce
  /// oluşturmuş olabilir. Var olan alanlar (ad, ayarlar) ezilmez.
  Future<void> ensureProfile({
    required String uid,
    required String email,
    String? adSoyad,
    String? telefon,
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
    };
    if (update.isNotEmpty) await ref.set(update, SetOptions(merge: true));

    final public = await _db.collection(_publicProfilesCollection).doc(uid).get();
    if (!public.exists || (public.data()?['adSoyad'] ?? '') != name) {
      await syncPublicProfile(uid, name);
    }
  }

  /// Açık profili olmayan eski hesaplar için girişte profili oluşturur.
  Future<void> ensurePublicProfile(String uid) async {
    final profile = await _db
        .collection(_publicProfilesCollection)
        .doc(uid)
        .get();
    if (profile.exists) return;
    final user = await getUser(uid);
    if (user != null) await syncPublicProfile(uid, user.adSoyad);
  }

  Future<UserModel?> getUser(String uid) async {
    final snapshot = await usersRef.doc(uid).get();
    return snapshot.data();
  }

  Stream<UserModel?> getUserStream(String uid) {
    return usersRef.doc(uid).snapshots().map((snapshot) => snapshot.data());
  }

  Future<String> getUserNameById(String userId) async {
    if (userId.isEmpty) return 'Bilinmeyen Kullanıcı';

    // Check cache first for performance
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }

    try {
      final profile = await _db
          .collection(_publicProfilesCollection)
          .doc(userId)
          .get();
      final adSoyad = (profile.data()?['adSoyad'] as String?)?.trim();
      final userName = (adSoyad == null || adSoyad.isEmpty)
          ? 'Bilinmeyen Kullanıcı'
          : adSoyad;

      // Cache the result
      _userNameCache[userId] = userName;
      return userName;
    } catch (e) {
      print('Error getting user name: $e');
      return 'Hata';
    }
  }

  /// E-postası doğrulanmış kayıtlı kullanıcıyı bulur.
  ///
  /// Kullanıcı listesi istemciye kapalıdır; arama `lookupUserByEmail`
  /// fonksiyonuyla Firebase Auth kaydı üzerinden yapılır. Böylece profildeki
  /// e-posta alanını değiştirerek başkasının yerine geçmek mümkün olmaz.
  Future<UserModel?> getUserByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    try {
      final result = await _functions
          .httpsCallable('lookupUserByEmail')
          .call({'email': normalized});
      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['found'] != true) return null;
      return UserModel(
        uid: data['uid'] as String,
        email: data['email'] as String? ?? normalized,
        adSoyad: data['adSoyad'] as String?,
      );
    } catch (e) {
      print('Error getting user by email: $e');
      return null;
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    if (uid.isEmpty || data.isEmpty) return;

    try {
      await usersRef.doc(uid).update(data);
      if (data.containsKey('adSoyad')) {
        await syncPublicProfile(uid, data['adSoyad'] as String?);
      }
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  // DEBT METHODS
  Future<String> addDebt(DebtModel debt) async {
    try {
      // createdAt server timestamp olacak şekilde ek alanlarla yaz
      final docRef = await _db.collection(_debtsCollection).add({
        ...debt.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      final newDebtId = docRef.id;

      // Not: İlk onay bildirimlerini Cloud Functions gönderiyor (onDebtCreate).
      // Burada tekrarlı bildirim oluşturmamak için client tarafında atlanır.
      return newDebtId;
    } catch (e) {
      print('ERROR adding debt: $e');
      return '';
    }
  }

  // Durum değişikliklerinin bildirimlerini Cloud Functions gönderir
  // (onDebtStatusUpdate, onDebtDelete). İstemci bildirim yazamaz; kimin hangi
  // geçişi yapabileceğini firestore.rules belirler.

  Future<void> updateDebtStatus(String debtId, String newStatus) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await debtsRef.doc(debtId).update({
      'status': newStatus,
      'updatedById': currentUser.uid,
    });
  }

  Future<void> requestDebtDeletion(String debtId, String requesterId) async {
    await debtsRef.doc(debtId).update({
      'status': statusPendingDeletion,
      'deletion_requester_id': requesterId,
    });
  }

  Future<void> respondToDeleteRequest(String debtId, bool approved) async {
    final debtRef = debtsRef.doc(debtId);
    final debtSnapshot = await debtRef.get();
    if (!debtSnapshot.exists) return;
    if (debtSnapshot.data()!.deletionRequesterId == null) return;

    if (approved) {
      await debtRef.delete();
    } else {
      await debtRef.update({
        'status': statusApproved,
        'deletion_requester_id': FieldValue.delete(),
      });
    }
  }

  Future<void> deleteDebt(String debtId) async {
    await debtsRef.doc(debtId).delete();
  }

  // Diğer metodlar (getSavedContacts, vs.) değişmeden kalır...
  // Bu metodları buraya eklemiyorum çünkü onlar değişmedi.

  Stream<List<DebtModel>> getUserDebtsStream(String userId) {
    return debtsRef
        .where('visibleto', arrayContains: userId)
        .orderBy('islemTarihi', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<DebtModel>> getRecentDebtsStream(String userId) {
    return debtsRef
        .where('visibleto', arrayContains: userId)
        .orderBy('islemTarihi', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<DebtModel?> getDebtByIdStream(String debtId) {
    return debtsRef.doc(debtId).snapshots().map((snapshot) => snapshot.data());
  }

  Stream<List<SavedContactModel>> getSavedContactsStream(String searchTerm) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    var query = _db
        .collection(_usersCollection)
        .doc(uid)
        .collection(_savedContactsCollection);
    return query.snapshots().map((snapshot) {
      try {
        var contacts = snapshot.docs
            .map((doc) => SavedContactModel.fromFirestore(doc))
            .toList();

        if (searchTerm.isNotEmpty) {
          final searchLower = searchTerm.toLowerCase();
          contacts = contacts
              .where(
                (c) =>
                    c.adSoyad.toLowerCase().contains(searchLower) ||
                    c.email.toLowerCase().contains(searchLower),
              )
              .toList();
        }

        contacts.sort((a, b) => a.adSoyad.compareTo(b.adSoyad));
        return contacts;
      } catch (e) {
        print('Error processing contacts stream: $e');
        return <SavedContactModel>[];
      }
    });
  }

  Future<void> toggleFavoriteContact(String contactId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userDocRef = usersRef.doc(uid);

    final doc = await userDocRef.get();
    final user = doc.data();
    if (user != null) {
      final favorites = List<String>.from(user.favoriteContacts ?? []);
      if (favorites.contains(contactId)) {
        favorites.remove(contactId);
      } else {
        favorites.add(contactId);
      }
      await userDocRef.update({'favoriteContacts': favorites});
    }
  }

  Future<void> addSavedContact(SavedContactModel contact) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection(_usersCollection)
        .doc(uid)
        .collection(_savedContactsCollection)
        .add(contact.toMap());
  }

  Stream<bool> getUnreadNotificationsStream(String userId) {
    return _db
        .collection(_notificationsCollection)
        .where('toUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    final querySnapshot = await _db
        .collection(_notificationsCollection)
        .where('toUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
