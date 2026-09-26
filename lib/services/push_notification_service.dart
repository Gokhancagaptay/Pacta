import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_routes.dart';

// Uygulama arka plandayken gelen bildirimler için; sınıf dışında olmalı.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Push bildirimleri: izin, cihaz anahtarı (fcmToken), ön planda gösterim ve
/// bildirime dokununca ilgili ekranın açılması.
class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'pacta_default_channel',
    'Genel Bildirimler',
    description: 'Pacta uygulaması için yüksek öncelikli bildirim kanalı',
    importance: Importance.high,
  );

  /// Son yazılan (kullanıcı, anahtar); aynısı tekrar yazılmaz.
  String? _savedFor;

  /// Uygulama açılışını bekletmez: runApp'tan sonra çağrılır.
  Future<void> initialize() async {
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (r) => NotificationRoutes.open(r.payload),
    );

    // Uygulamayı bildirim açtıysa (yerel ya da FCM) ilgili kayda git.
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      NotificationRoutes.open(launch!.notificationResponse?.payload);
    }
    final initial = await _fcm.getInitialMessage();
    if (initial != null) NotificationRoutes.open(initial.data['route'] as String?);
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => NotificationRoutes.open(m.data['route'] as String?),
    );

    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // userChanges: e-posta doğrulanınca da yayın yapar; anahtar ancak
    // doğrulanmış hesaba yazılır.
    _auth.userChanges().listen((_) => unawaited(_saveCurrentToken()));
    _fcm.onTokenRefresh.listen((token) => unawaited(_saveToken(token)));

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_showForeground);
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notif.title ?? 'Bildirim',
      notif.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: message.data['route'] as String?,
    );
  }

  Future<void> _saveCurrentToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      if (kDebugMode) debugPrint('FCM anahtarı alınamadı: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final unverified =
        !user.emailVerified &&
        user.providerData.any((p) => p.providerId == 'password');
    if (unverified) return;
    final key = '${user.uid}:$token';
    if (_savedFor == key) return;
    _savedFor = key;
    try {
      // Belge yoksa oluşturur; profil AuthWrapper'da eksik alanlarıyla
      // tamamlanır (kurallar buna izin verir).
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    } catch (e) {
      _savedFor = null;
      if (kDebugMode) debugPrint('FCM anahtarı kaydedilemedi: $e');
    }
  }
}
