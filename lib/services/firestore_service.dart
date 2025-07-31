// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pacta/models/debt_model.dart';
import 'package:pacta/models/saved_contact_model.dart';
import 'package:pacta/models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final CollectionReference<UserModel> usersRef;
  late final CollectionReference<DebtModel> debtsRef;

  FirestoreService() {
    usersRef = _db
        .collection('users')
        .withConverter<UserModel>(
          fromFirestore: (snapshot, _) => UserModel.fromMap(snapshot.data()!),
          toFirestore: (user, _) => user.toMap(),
        );

    debtsRef = _db
        .collection('debts')
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

  Stream<UserModel?> getUserStream(String uid) {
    return usersRef.doc(uid).snapshots().map((snapshot) => snapshot.data());
  }

  Future<String> getUserNameById(String userId) async {
    if (userId.isEmpty) return 'Bilinmeyen Kullanıcı';
    try {
      final doc = await usersRef.doc(userId).get();
      if (doc.exists) {
        final user = doc.data();
        if (user != null) return user.adSoyad ?? user.email;
      }
      return 'Bilinmeyen Kullanıcı';
    } catch (e) {
      print('Error getting user name: $e');
      return 'Hata';
    }
  }

  Future<UserModel?> getUserByEmail(String email) async {
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

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await usersRef.doc(uid).update(data);
  }

  Future<List<UserModel>> getSavedContacts(String uid) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('savedContacts')
          .where('uid', isNotEqualTo: null) // Sadece gerçek kullanıcıları al
          .get();

      if (snapshot.docs.isEmpty) return [];

      // Kayıtlı kişilerin UID'lerini bir liste yap
      final contactUids = snapshot.docs
          .map((doc) => doc.data()['uid'] as String)
          .toList();

      if (contactUids.isEmpty) return [];

      // Bu UID'lere sahip kullanıcıları getir
      final usersSnapshot = await usersRef
          .where(FieldPath.documentId, whereIn: contactUids)
          .get();

      return usersSnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting saved contacts: $e');
      return [];
    }
  }

  // DEBT METHODS
  Future<String> addDebt(DebtModel debt) async {
    try {
      // 1. Borcu 'debts' koleksiyonuna ekle ve referansını al
      final docRef = await debtsRef.add(debt);

      // 2. Eğer bu bir 'note' değilse, bildirim gönder
      if (debt.status != 'note') {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return ''; // Return empty string on error

        // Bildirimi alacak olan diğer tarafı belirle
        final toUserId = debt.alacakliId == currentUser.uid
            ? debt.borcluId
            : debt.alacakliId;

        final borcluName = await getUserNameById(debt.borcluId);
        final alacakliName = await getUserNameById(debt.alacakliId);

        final title = debt.alacakliId == currentUser.uid
            ? "Yeni Borç Bildirimi"
            : "Yeni Alacak Talebi";

        final message = debt.alacakliId == currentUser.uid
            ? "$alacakliName size ${debt.miktar}₺ tutarında bir borç bildiriminde bulundu."
            : "$borcluName sizden ${debt.miktar}₺ tutarında bir alacak talebinde bulundu.";

        await sendNotification(
          toUserId: toUserId,
          createdById: currentUser.uid,
          type: 'approval_request',
          relatedDebtId: docRef.id,
          title: title,
          message: message,
          debtorId: debt.alacakliId,
          creditorId: debt.borcluId,
          amount: debt.miktar,
        );
      }
      return docRef.id; // Return the document ID
    } catch (e) {
      print('Error adding debt: $e');
      return ''; // Return empty string on error
    }
  }

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

  Future<void> updateDebtStatus(String debtId, String newStatus) async {
    await debtsRef.doc(debtId).update({'status': newStatus});
  }

  // SAVED CONTACTS METHODS
  Stream<List<SavedContactModel>> getSavedContactsStream(String searchTerm) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    var query = _db.collection('users').doc(uid).collection('savedContacts');
    return query.snapshots().map((snapshot) {
      var contacts = snapshot.docs
          .map((doc) => SavedContactModel.fromFirestore(doc))
          .toList();
      if (searchTerm.isNotEmpty) {
        contacts = contacts
            .where(
              (c) =>
                  c.adSoyad.toLowerCase().contains(searchTerm.toLowerCase()) ||
                  c.email.toLowerCase().contains(searchTerm.toLowerCase()),
            )
            .toList();
      }
      contacts.sort((a, b) => a.adSoyad.compareTo(b.adSoyad));
      return contacts;
    });
  }

  // Favori Ekle/Çıkar
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
        .collection('users')
        .doc(uid)
        .collection('savedContacts')
        .add(contact.toMap());
  }

  // NOTIFICATION METHODS
  Stream<bool> getUnreadNotificationsStream(String userId) {
    return _db
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    final querySnapshot = await _db
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> sendNotification({
    required String toUserId,
    required String type,
    String? relatedDebtId,
    required String title,
    required String message,
    String? createdById,
    // Yeni parametreler
    required String debtorId,
    required String creditorId,
    required double amount,
  }) async {
    await _db.collection('notifications').add({
      'toUserId': toUserId,
      'type': type,
      'relatedDebtId': relatedDebtId,
      'title': title,
      'message': message,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'createdById': createdById,
      // Yeni alanların Firestore'a yazılması
      'debtorId': debtorId,
      'creditorId': creditorId,
      'amount': amount,
    });
  }
}
