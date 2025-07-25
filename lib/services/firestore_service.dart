// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/debt_model.dart'; // Yeni DebtModel'i import ediyoruz
import '../models/user_model.dart';
import '../models/saved_contact_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final CollectionReference<UserModel> usersRef;
  late final CollectionReference<DebtModel> _debtsRef; // Borçlar için referans
  CollectionReference<DebtModel> get debtsRef => _debtsRef;

  FirestoreService() {
    usersRef = _db
        .collection('users')
        .withConverter<UserModel>(
          fromFirestore: (snapshots, _) => UserModel.fromMap(snapshots.data()!),
          toFirestore: (user, _) => user.toMap(),
        );

    // YENİ: Borçlar koleksiyonu için withConverter
    _debtsRef = _db
        .collection('debts')
        .withConverter<DebtModel>(
          fromFirestore: (snapshots, options) =>
              DebtModel.fromMap(snapshots.data()!, snapshots.id),
          toFirestore: (debt, options) => debt.toMap(),
        );
  }

  Future<void> kullaniciOlustur(UserModel user) async {
    try {
      await usersRef.doc(user.uid).set(user);
    } catch (e) {
      print("Firestore'a kullanıcı kaydedilirken hata oluştu: $e");
    }
  }

  Future<UserModel?> searchUserByEmail(String email) async {
    try {
      final querySnapshot = await usersRef
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      print("Kullanıcı aranırken hata oluştu: $e");
      return null;
    }
  }

  Future<UserModel?> searchUserByAny(String input) async {
    try {
      // E-posta ile arama
      var query = await usersRef
          .where('email', isEqualTo: input)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return query.docs.first.data();
      // Telefon ile arama
      query = await usersRef.where('telefon', isEqualTo: input).limit(1).get();
      if (query.docs.isNotEmpty) return query.docs.first.data();
      // Etiket ile arama
      query = await usersRef.where('etiket', isEqualTo: input).limit(1).get();
      if (query.docs.isNotEmpty) return query.docs.first.data();
      return null;
    } catch (e) {
      print('Kullanıcı ararken hata: $e');
      return null;
    }
  }

  // GÜNCELLENMİŞ VE DOĞRU METOD
  // Bu metod, yeni DebtModel'i Firestore'a ekler.
  Future<void> addDebt(DebtModel debt) async {
    try {
      final docRef = await _debtsRef.add(debt);
      await docRef.update({'debtId': docRef.id});
      // --- Her iki kullanıcı için recentDebts alt koleksiyonuna ekle ---
      final involvedUserIds = <String>{debt.alacakliId, debt.borcluId};
      for (final userId in involvedUserIds) {
        if (userId.isEmpty) continue;
        final recentRef = _db
            .collection('users')
            .doc(userId)
            .collection('recentDebts');
        await recentRef.doc(docRef.id).set(debt.toMap());
        // Son 5'ten fazlası varsa en eskiyi sil
        final recentDocs = await recentRef
            .orderBy('islemTarihi', descending: true)
            .get();
        if (recentDocs.docs.length > 5) {
          for (var i = 5; i < recentDocs.docs.length; i++) {
            await recentRef.doc(recentDocs.docs[i].id).delete();
          }
        }
      }
      // Borç onay bekliyorsa borçluya bildirim gönder (try bloğu içinde olmalı)
      if (debt.status == 'pending') {
        // Borcu oluşturan kişinin ad-soyadını Firestore'dan çekiyoruz
        final alacakliAdSoyad = await getUserNameById(debt.alacakliId);
        // Bildirim gönderiyoruz, mesajda ad-soyadı kullanıyoruz
        await sendNotification(
          toUserId: debt.borcluId,
          type: 'approval_request',
          relatedDebtId: docRef.id,
          title: 'Yeni Pacta Talebi',
          massage: '$alacakliAdSoyad senden ${debt.miktar} Borç istedi.',
        );
      }
    } catch (e) {
      print("Borç eklenirken hata oluştu: $e");
    }
  }

  // Kullanıcının borçlu veya alacaklı olduğu tüm borçlar
  Future<List<DebtModel>> getUserDebts(String userId) async {
    try {
      final query = await _debtsRef.where('borcluId', isEqualTo: userId).get();
      final query2 = await _debtsRef
          .where('alacakliId', isEqualTo: userId)
          .get();
      final debts = <DebtModel>[];
      debts.addAll(query.docs.map((doc) => doc.data()));
      debts.addAll(query2.docs.map((doc) => doc.data()));
      debts.sort((a, b) => b.islemTarihi.compareTo(a.islemTarihi));
      return debts;
    } catch (e) {
      print('Kullanıcı borçları çekilirken hata oluştu: $e');
      return [];
    }
  }

  // Kullanıcının borçlu veya alacaklı olduğu tüm borçlar (Stream)
  Stream<List<DebtModel>> getUserDebtsStream(String userId) {
    final borcluStream = _debtsRef
        .where('borcluId', isEqualTo: userId)
        .snapshots();
    final alacakliStream = _debtsRef
        .where('alacakliId', isEqualTo: userId)
        .snapshots();
    return borcluStream.asyncMap((borcluSnap) async {
      final alacakliSnap = await alacakliStream.first;
      final debts = <DebtModel>[];
      debts.addAll(borcluSnap.docs.map((doc) => doc.data()));
      debts.addAll(alacakliSnap.docs.map((doc) => doc.data()));
      debts.sort((a, b) => b.islemTarihi.compareTo(a.islemTarihi));
      return debts;
    });
  }

  // Kullanıcının belirli status'e sahip borçları
  Future<List<DebtModel>> getUserDebtsByStatus(
    String userId,
    String status,
  ) async {
    try {
      final query = await _debtsRef
          .where('borcluId', isEqualTo: userId)
          .where('status', isEqualTo: status)
          .get();
      final query2 = await _debtsRef
          .where('alacakliId', isEqualTo: userId)
          .where('status', isEqualTo: status)
          .get();
      final debts = <DebtModel>[];
      debts.addAll(query.docs.map((doc) => doc.data()));
      debts.addAll(query2.docs.map((doc) => doc.data()));
      debts.sort((a, b) => b.islemTarihi.compareTo(a.islemTarihi));
      return debts;
    } catch (e) {
      print('Kullanıcı borçları (status) çekilirken hata oluştu: $e');
      return [];
    }
  }

  // Kullanıcının recentDebts alt koleksiyonundaki son 5 işlem
  Future<List<DebtModel>> getRecentDebts(String userId) async {
    try {
      final query = await _db
          .collection('users')
          .doc(userId)
          .collection('recentDebts')
          .orderBy('islemTarihi', descending: true)
          .limit(5)
          .get();
      return query.docs
          .map((doc) => DebtModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('RecentDebts çekilirken hata oluştu: $e');
      return [];
    }
  }

  // Kullanıcının recentDebts alt koleksiyonundaki son 5 işlem (Stream)
  Stream<List<DebtModel>> getRecentDebtsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('recentDebts')
        .orderBy('islemTarihi', descending: true)
        .limit(5)
        .snapshots()
        .map(
          (query) => query.docs
              .map((doc) => DebtModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Kayıtlı kişi ekle
  Future<void> addSavedContact(
    String ownerUserId,
    SavedContactModel contact,
  ) async {
    try {
      await _db
          .collection('users')
          .doc(ownerUserId)
          .collection('savedContacts')
          .doc(contact.uid)
          .set(contact.toMap());
    } catch (e) {
      print('Kayıtlı kişi eklenirken hata oluştu: $e');
    }
  }

  // Kayıtlı kişi sil
  Future<void> deleteSavedContact(String ownerUserId, String contactUid) async {
    try {
      await _db
          .collection('users')
          .doc(ownerUserId)
          .collection('savedContacts')
          .doc(contactUid)
          .delete();
    } catch (e) {
      print('Kayıtlı kişi silinirken hata oluştu: $e');
    }
  }

  // Kayıtlı kişileri listele
  Future<List<SavedContactModel>> getSavedContacts(String ownerUserId) async {
    try {
      final query = await _db
          .collection('users')
          .doc(ownerUserId)
          .collection('savedContacts')
          .get();
      return query.docs
          .map((doc) => SavedContactModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Kayıtlı kişiler çekilirken hata oluştu: $e');
      return [];
    }
  }

  // Kullanıcı id'sinden adSoyad bilgisini getirir
  Future<String> getUserNameById(String uid) async {
    try {
      final doc = await usersRef.doc(uid).get();
      final user = doc.data();
      if (user != null && user.adSoyad != null && user.adSoyad!.isNotEmpty) {
        return user.adSoyad!;
      } else if (user != null && user.email.isNotEmpty) {
        return user.email;
      } else {
        // UID 6 karakterden kısaysa tamamını döndür, uzun ise ilk 6 karakterini döndür
        return uid.length >= 6 ? uid.substring(0, 6) : uid;
      }
    } catch (e) {
      return uid.substring(0, 6);
    }
  }

  // Borç status güncelleme fonksiyonu
  Future<void> updateDebtStatus(String debtId, String status) async {
    try {
      await _debtsRef.doc(debtId).update({'status': status});
      // Ana koleksiyon güncellendi, şimdi recentDebts alt koleksiyonlarını da güncelle
      final doc = await _debtsRef.doc(debtId).get();
      final debt = doc.data();
      if (debt != null) {
        final userIds = <String>{debt.alacakliId, debt.borcluId};
        for (final userId in userIds) {
          if (userId.isEmpty) continue;
          final recentRef = _db
              .collection('users')
              .doc(userId)
              .collection('recentDebts')
              .doc(debtId);
          try {
            await recentRef.update({'status': status});
          } catch (e) {
            // Eğer update başarısızsa (kayıt yoksa), tüm alanlarla set et
            await recentRef.set(debt.toMap()..['status'] = status);
          }
        }
      }
    } catch (e) {
      print('Borç durumu güncellenirken hata oluştu: $e');
    }
  }

  // Tekil borcu stream ile getirir
  Stream<DebtModel?> getDebtByIdStream(String debtId) {
    return _debtsRef.doc(debtId).snapshots().map((doc) => doc.data());
  }

  Future<void> sendNotification({
    required String toUserId,
    required String type,
    required String relatedDebtId,
    required String title,
    required String massage,
  }) async {
    await _db.collection('notifications').add({
      'toUserId': toUserId,
      'type': type,
      'relatedDebtId': relatedDebtId,
      'title': title,
      'massage': massage,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
