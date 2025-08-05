// lib/models/user_model.dart

class NotificationSettings {
  final bool newDebtRequests;
  final bool statusChanges;
  final bool paymentReminders;
  final bool promotionsAndNews;

  NotificationSettings({
    this.newDebtRequests = true,
    this.statusChanges = true,
    this.paymentReminders = false, // Varsayılan olarak kapalı
    this.promotionsAndNews = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'newDebtRequests': newDebtRequests,
      'statusChanges': statusChanges,
      'paymentReminders': paymentReminders,
      'promotionsAndNews': promotionsAndNews,
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return NotificationSettings(); // Harita boşsa varsayılan ayarları döndür
    }
    return NotificationSettings(
      newDebtRequests: map['newDebtRequests'] ?? true,
      statusChanges: map['statusChanges'] ?? true,
      paymentReminders: map['paymentReminders'] ?? false,
      promotionsAndNews: map['promotionsAndNews'] ?? true,
    );
  }
}

class UserModel {
  final String uid;
  final String email;
  final String? adSoyad;
  final String? telefon;
  final String? etiket;
  final List<String>? aramaAnahtarlari;
  final List<String>? favoriteContacts;
  final NotificationSettings notificationSettings; // YENİ: Bildirim ayarları

  UserModel({
    required this.uid,
    required this.email,
    this.adSoyad,
    this.telefon,
    this.etiket,
    this.aramaAnahtarlari,
    this.favoriteContacts,
    NotificationSettings? notificationSettings,
  }) : notificationSettings = notificationSettings ?? NotificationSettings();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'adSoyad': adSoyad,
      'telefon': telefon,
      'etiket': etiket,
      'aramaAnahtarlari': aramaAnahtarlari ?? [],
      'favoriteContacts': favoriteContacts ?? [],
      'notificationSettings': notificationSettings.toMap(), // YENİ
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      adSoyad: map['adSoyad'],
      telefon: map['telefon'],
      etiket: map['etiket'],
      aramaAnahtarlari: map['aramaAnahtarlari'] == null
          ? null
          : List<String>.from(map['aramaAnahtarlari']),
      favoriteContacts: List<String>.from(map['favoriteContacts'] ?? []),
      notificationSettings: NotificationSettings.fromMap(
        map['notificationSettings'],
      ), // YENİ
    );
  }
}
