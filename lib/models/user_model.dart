// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationSettings {
  final bool newDebtRequests;
  final bool statusChanges;
  final bool paymentReminders;
  final bool promotionsAndNews;

  /// v2 hatırlatmalar (kişi hatırlatmaları ve vade bildirimleri); varsayılan açık.
  final bool reminders;

  NotificationSettings({
    this.newDebtRequests = true,
    this.statusChanges = true,
    this.paymentReminders = false, // Varsayılan olarak kapalı
    // Pazarlama izni kullanıcı açıkça vermedikçe yoktur (İYS/KVKK).
    this.promotionsAndNews = false,
    this.reminders = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'newDebtRequests': newDebtRequests,
      'statusChanges': statusChanges,
      'paymentReminders': paymentReminders,
      'promotionsAndNews': promotionsAndNews,
      'reminders': reminders,
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
      reminders: map['reminders'] ?? true,
    );
  }
}

class UserModel {
  final String uid;
  final String email;
  final String? adSoyad;
  final String? telefon;

  /// Push bildirimi tercihleri.
  final NotificationSettings notificationSettings;

  /// Hatırlatmaları sessize alınan defterler (push gelmez, bildirim listesi kalır).
  final Set<String> reminderMutes;

  /// Favori kişiler (defter kimliği); listelerde başta durur.
  final Set<String> favoriteLedgers;

  /// Listeden kaldırılan defterler ve kaldırılma anı. Sonra yeni hareket
  /// olursa defter yeniden görünür.
  final Map<String, DateTime> hiddenLedgers;

  /// Kişinin Pacta kodu (QR ve davet linki bunu taşır); sunucu üretir.
  final String? pactaCode;

  /// Kabul edilen Kullanım Koşulları sürümü (AppConstants.termsVersion).
  final String? termsVersion;

  UserModel({
    required this.uid,
    required this.email,
    this.adSoyad,
    this.telefon,
    NotificationSettings? notificationSettings,
    this.reminderMutes = const {},
    this.favoriteLedgers = const {},
    this.hiddenLedgers = const {},
    this.pactaCode,
    this.termsVersion,
  }) : notificationSettings = notificationSettings ?? NotificationSettings();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'adSoyad': adSoyad,
      'telefon': telefon,
      'notificationSettings': notificationSettings.toMap(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      adSoyad: map['adSoyad'],
      telefon: map['telefon'],
      notificationSettings: NotificationSettings.fromMap(
        map['notificationSettings'],
      ),
      reminderMutes: {
        for (final e in ((map['reminderMutes'] as Map?) ?? const {}).entries)
          if (e.value == true) e.key as String,
      },
      favoriteLedgers: {
        for (final e in ((map['favoriteLedgers'] as Map?) ?? const {}).entries)
          if (e.value == true) e.key as String,
      },
      hiddenLedgers: {
        for (final e in ((map['hiddenLedgers'] as Map?) ?? const {}).entries)
          // Sunucu zamanı henüz yazılmadıysa (yerel önbellek) "şimdi".
          e.key as String: e.value is Timestamp
              ? (e.value as Timestamp).toDate()
              : DateTime.now(),
      },
      pactaCode: map['pactaCode'] as String?,
      termsVersion: map['termsVersion'] as String?,
    );
  }
}
