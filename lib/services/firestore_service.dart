// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
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
  late final CollectionReference<UserModel> usersRef;
  late final CollectionReference<DebtModel> debtsRef;

  // Use constants from AppConstants
  static const String _usersCollection = AppConstants.usersCollection;
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
      final user = await getUser(userId);
      final userName = user?.adSoyad ?? user?.email ?? 'Bilinmeyen Kullanıcı';

      // Cache the result
      _userNameCache[userId] = userName;
      return userName;
    } catch (e) {
      print('Error getting user name: $e');
      return 'Hata';
    }
  }

  Future<UserModel?> getUserByEmail(String email) async {
    if (email.isEmpty) return null;

    try {
      final querySnapshot = await usersRef
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) return querySnapshot.docs.first.data();
      return null;
    } catch (e) {
      print('Error getting user by email: $e');
      return null;
    }
  }

  /// E-postayı küçük harfe çevirip `aramaAnahtarlari` üzerinden arar (case-insensitive)
  Future<UserModel?> getUserByEmailInsensitive(String email) async {
    if (email.isEmpty) return null;
    try {
      final lower = email.toLowerCase();
      final querySnapshot = await usersRef
          .where('aramaAnahtarlari', arrayContains: lower)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) return querySnapshot.docs.first.data();
      return await getUserByEmail(email); // son çare eşitlik kontrolü
    } catch (e) {
      print('Error getting user by email insensitive: $e');
      return null;
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    if (uid.isEmpty || data.isEmpty) return;

    try {
      await usersRef.doc(uid).update(data);
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

  Future<void> updateDebtStatus(String debtId, String newStatus) async {
    final debtRef = debtsRef.doc(debtId);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final debtSnapshot = await debtRef.get();
    final debt = debtSnapshot.data();
    if (debt == null) return;

    await debtRef.update({'status': newStatus, 'updatedById': currentUser.uid});

    if (newStatus == statusApproved || newStatus == statusRejected) {
      final updatedByName = await getUserNameById(currentUser.uid);
      final createdBy = debt.createdBy;

      if (createdBy != null && createdBy != currentUser.uid) {
        final message = newStatus == statusApproved
            ? '${debt.miktar.toStringAsFixed(2)}₺ tutarındaki işleminiz $updatedByName tarafından onaylandı.'
            : '${debt.miktar.toStringAsFixed(2)}₺ tutarındaki işleminiz $updatedByName tarafından reddedildi.';

        await sendNotification(
          toUserId: createdBy,
          createdById: currentUser.uid,
          type: newStatus == statusApproved
              ? 'request_approved'
              : 'request_rejected',
          relatedDebtId: debtId,
          message: message,
          debtorId: debt.borcluId,
          creditorId: debt.alacakliId,
          amount: debt.miktar,
        );
      }
    }
  }

  /// Kullanıcı kendi adına bir borcu onaylar (ör: borçlu kişi ödemeyi kabul eder)
  /// Mevcut `updateDebtStatus`i kullanır; UI'dan tek çağrı yeterlidir.
  Future<String?> approveDebtByUser(String debtId) async {
    try {
      await updateDebtStatus(debtId, statusApproved);
      return null;
    } catch (e) {
      return 'İşlem onaylanırken hata oluştu.';
    }
  }

  /// Anında onaylı borç/ödeme kaydı oluşturur (karşı tarafla arada onay gerektirmez)
  /// iAmDebtor=true ise currentUser borçludur; aksi halde alacaklıdır.
  Future<String?> createInstantApprovedDebt({
    required String otherUserId,
    required double amount,
    required bool iAmDebtor,
    String? aciklama,
    DateTime? islemTarihi,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 'Kullanıcı oturumu bulunamadı.';
    try {
      final debt = DebtModel(
        borcluId: iAmDebtor ? currentUser.uid : otherUserId,
        alacakliId: iAmDebtor ? otherUserId : currentUser.uid,
        miktar: amount,
        aciklama: aciklama,
        islemTarihi: islemTarihi ?? DateTime.now(),
        tahminiOdemeTarihi: null,
        createdAt: DateTime.now(),
        dueReminderSent: false,
        status: statusApproved,
        isShared: true,
        requiresApproval: false,
        visibleto: [currentUser.uid, otherUserId],
        createdBy: currentUser.uid,
      );
      final newId = await addDebt(debt);
      if (newId.isEmpty) return 'Kayıt oluşturulamadı.';
      return null;
    } catch (e) {
      print('createInstantApprovedDebt error: $e');
      return 'Kayıt oluşturulurken hata oluştu.';
    }
  }

  /// Karşı taraftan ödeme talebi bildirimi gönderir (in-app notification)
  Future<String?> requestPayment(String debtId, String requesterId) async {
    try {
      final snap = await debtsRef.doc(debtId).get();
      final debt = snap.data();
      if (debt == null) return 'Kayıt bulunamadı.';
      final toUserId = requesterId == debt.alacakliId
          ? debt.borcluId
          : debt.alacakliId;
      final requesterName = await getUserNameById(requesterId);
      await sendNotification(
        toUserId: toUserId,
        createdById: requesterId,
        type: 'payment_request',
        relatedDebtId: debtId,
        message:
            '$requesterName, ${debt.miktar.toStringAsFixed(2)}₺ tutarındaki borç için ödeme talep ediyor.',
        debtorId: debt.borcluId,
        creditorId: debt.alacakliId,
        amount: debt.miktar,
      );
      return null;
    } catch (e) {
      print('requestPayment error: $e');
      return 'Ödeme talebi gönderilemedi.';
    }
  }

  Future<void> requestDebtDeletion(String debtId, String requesterId) async {
    final debtRef = debtsRef.doc(debtId);
    final debtSnapshot = await debtRef.get();
    if (!debtSnapshot.exists) return;
    final debt = debtSnapshot.data()!;

    await debtRef.update({
      'status': statusPendingDeletion,
      'deletion_requester_id': requesterId,
    });

    final otherPartyId = requesterId == debt.alacakliId
        ? debt.borcluId
        : debt.alacakliId;
    final requesterName = await getUserNameById(requesterId);

    await sendNotification(
      toUserId: otherPartyId,
      createdById: requesterId,
      type: 'deletion_request',
      relatedDebtId: debtId,
      message:
          '$requesterName, ${debt.miktar.toStringAsFixed(2)}₺ tutarındaki işlemi silmek istiyor.',
      debtorId: debt.borcluId,
      creditorId: debt.alacakliId,
      amount: debt.miktar,
    );
  }

  Future<void> respondToDeleteRequest(
    String debtId,
    bool approved,
    String responderId,
  ) async {
    final debtRef = debtsRef.doc(debtId);
    final debtSnapshot = await debtRef.get();
    if (!debtSnapshot.exists) return;
    final debt = debtSnapshot.data()!;
    final requesterId = debt.deletionRequesterId;

    if (requesterId == null) return;

    if (approved) {
      await debtRef.delete();
    } else {
      await debtRef.update({
        'status': 'approved',
        'deletion_requester_id': FieldValue.delete(),
      });
    }

    final responderName = await getUserNameById(responderId);
    final message = approved
        ? '$responderName, ${debt.miktar.toStringAsFixed(2)}₺ tutarındaki işlemin silinmesini onayladı.'
        : '$responderName, ${debt.miktar.toStringAsFixed(2)}₺ tutarındaki işlemin silinmesini reddetti.';

    await sendNotification(
      toUserId: requesterId,
      createdById: responderId,
      type: approved ? 'deletion_approved' : 'deletion_rejected',
      relatedDebtId: debtId,
      message: message,
      debtorId: debt.borcluId,
      creditorId: debt.alacakliId,
      amount: debt.miktar,
    );
  }

  Future<void> deleteDebt(String debtId) async {
    await debtsRef.doc(debtId).delete();
  }

  // NOTIFICATION METHODS
  Future<void> sendNotification({
    required String toUserId,
    required String type,
    String? relatedDebtId,
    required String message,
    String? createdById,
    required String debtorId,
    required String creditorId,
    required double amount,
  }) async {
    await _db.collection(_notificationsCollection).add({
      'toUserId': toUserId,
      'type': type,
      'relatedDebtId': relatedDebtId,
      'title': '', // Title artık gereksiz, mesajda her şey var.
      'message': message,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'createdById': createdById,
      'debtorId': debtorId,
      'creditorId': creditorId,
      'amount': amount,
    });
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
