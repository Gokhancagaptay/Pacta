// lib/models/user_model.dart

class UserModel {
  final String uid;
  final String email;
  final String? adSoyad;
  final String? telefon; // YENİ: Telefon numarası alanı
  final String? etiket; // YENİ: 3 haneli etiket
  final List<String> aramaAnahtarlari; // YENİ: Arama için anahtar kelimeler

  UserModel({
    required this.uid,
    required this.email,
    this.adSoyad,
    this.telefon,
    this.etiket,
    required this.aramaAnahtarlari,
  });

  // Firestore'a yazmak için
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'adSoyad': adSoyad,
      'telefon': telefon,
      'etiket': etiket,
      'aramaAnahtarlari': aramaAnahtarlari,
    };
  }

  // Firestore'dan okumak için
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      adSoyad: map['adSoyad'],
      telefon: map['telefon'],
      etiket: map['etiket'],
      // Gelen liste dynamic olabileceğinden List<String>'e çeviriyoruz
      aramaAnahtarlari: List<String>.from(map['aramaAnahtarlari'] ?? []),
    );
  }
}
