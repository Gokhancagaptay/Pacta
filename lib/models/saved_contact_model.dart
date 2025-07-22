class SavedContactModel {
  final String uid; // Kayıtlı kişinin userId'si
  final String adSoyad;
  final String email;

  SavedContactModel({
    required this.uid,
    required this.adSoyad,
    required this.email,
  });

  Map<String, dynamic> toMap() {
    return {'uid': uid, 'adSoyad': adSoyad, 'email': email};
  }

  factory SavedContactModel.fromMap(Map<String, dynamic> map) {
    return SavedContactModel(
      uid: map['uid'] ?? '',
      adSoyad: map['adSoyad'] ?? '',
      email: map['email'] ?? '',
    );
  }
}
