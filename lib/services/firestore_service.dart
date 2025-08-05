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

  Future<UserModel?> getUser(String uid) async {
    final snapshot = await usersRef.doc(uid).get();
    return snapshot.data();
  }

  Stream<UserModel?> getUserStream(String uid) {
    return usersRef.doc(uid).snapshots().map((snapshot) => snapshot.data());
  }

  Future<String> getUserNameById(String userId) async {
    if (userId.isEmpty) return 'Bilinmeyen Kullanıcı';
    try {
      final user = await getUser(userId);
      if (user != null) return user.adSoyad ?? user.email;
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

  // DEBT METHODS
  Future<String> addDebt(DebtModel debt) async {
    try {
      final docRef = await debtsRef.add(debt);
      final newDebtId = docRef.id;

      if (debt.requiresApproval && debt.status == 'pending') {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final currentUserName = await getUserNameById(currentUser.uid);
          final toUserId = debt.createdBy == debt.alacakliId
              ? debt.borcluId
              : debt.alacakliId;

          await sendNotification(
            toUserId: toUserId,
            createdById: currentUser.uid,
            type: 'approval_request',
            relatedDebtId: newDebtId,
            message:
                '$currentUserName, sizinle arasında ${debt.miktar.toStringAsFixed(2)}₺ tutarında bir işlem oluşturdu.',
            debtorId: debt.borcluId,
            creditorId: debt.alacakliId,
            amount: debt.miktar,
          );
        }
      }
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

    if (newStatus == 'approved' || newStatus == 'rejected') {
      final updatedByName = await getUserNameById(currentUser.uid);
      final createdBy = debt.createdBy;

      if (createdBy != null && createdBy != currentUser.uid) {
        final message = newStatus == 'approved'
            ? '${debt.miktar.toStringAsFixed(2)}₺ tutarındaki işleminiz $updatedByName tarafından onaylandı.'
            : '${debt.miktar.toStringAsFixed(2)}₺ tutarındaki işleminiz $updatedByName tarafından reddedildi.';

        await sendNotification(
          toUserId: createdBy,
          createdById: currentUser.uid,
          type: newStatus == 'approved'
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

  Future<void> requestDebtDeletion(String debtId, String requesterId) async {
    final debtRef = debtsRef.doc(debtId);
    final debtSnapshot = await debtRef.get();
    if (!debtSnapshot.exists) return;
    final debt = debtSnapshot.data()!;

    await debtRef.update({
      'status': 'pending_deletion',
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
    await _db.collection('notifications').add({
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
}
