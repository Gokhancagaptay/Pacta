import 'package:cloud_firestore/cloud_firestore.dart';

class SavedContactModel {
  final String? id;
  final String adSoyad;
  final String email;
  final String? uid; // Gerçek kullanıcı ise UID'si

  SavedContactModel({
    this.id,
    required this.adSoyad,
    required this.email,
    this.uid,
  });

  Map<String, dynamic> toMap() {
    return {'adSoyad': adSoyad, 'email': email, 'uid': uid};
  }

  factory SavedContactModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavedContactModel(
      id: doc.id,
      adSoyad: data['adSoyad'] ?? '',
      email: data['email'] ?? '',
      uid: data['uid'],
    );
  }
}
