// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/debt_model.dart'; // Yeni DebtModel'i import ediyoruz
import '../models/user_model.dart';
import '../models/saved_contact_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final CollectionReference<UserModel> usersRef;
  late final CollectionReference<DebtModel> _debtsRef; // Borçlar için referans

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
    } catch (e) {
      print("Borç eklenirken hata oluştu: $e");
    }
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
}
