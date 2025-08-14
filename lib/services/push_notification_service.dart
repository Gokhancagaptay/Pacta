import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

// Uygulama arkaplandayken (ama tamamen kapalı değilken) gelen bildirimleri işlemek için.
// Bu fonksiyonun sınıf dışında, en üst seviyede bir fonksiyon olması gerekiyor.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Burada arkaplan bildirimleriyle ilgili bir işlem yapmak isterseniz yapabilirsiniz.
  // Örneğin, bir loglama veya yerel bir veritabanı güncellemesi.
  print("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Android notification channel (high importance)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'pacta_default_channel',
      'Genel Bildirimler',
      description: 'Pacta uygulaması için yüksek öncelikli bildirim kanalı',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );
    await _local.initialize(initSettings);
    // 1. Bildirim İzinlerini İste
    await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // 2. FCM Token'ı: Giriş sonrasında garanti kayıt
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        final token = await _fcm.getToken();
        if (kDebugMode) {
          print("FCM Token (login): $token");
        }
        if (token != null) {
          await saveTokenToDatabase(token);
        }
      }
    });
    // Uygulama açılışında kullanıcı varsa yaz
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final token = await _fcm.getToken();
      if (kDebugMode) {
        print("FCM Token (cold start): $token");
      }
      if (token != null) {
        await saveTokenToDatabase(token);
      }
    }
    // Token her yenilendiğinde veritabanını güncelle
    _fcm.onTokenRefresh.listen(saveTokenToDatabase);

    // 3. Arkaplan Mesaj Handler'ını Ayarla
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Uygulama açıkken gelen bildirimleri dinle
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        final notif = message.notification!;
        await _local.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          notif.title ?? 'Bildirim',
          notif.body ?? '',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'pacta_default_channel',
              'Genel Bildirimler',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }

      // iOS için foreground’da gösterim izni (Android 13+ için de kanallar/importance gerekli)
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    });
  }

  Future<void> saveTokenToDatabase(String token) async {
    // Giriş yapmış kullanıcının ID'sini al
    User? user = _auth.currentUser;

    if (user != null) {
      // Her durumda `set` ile `merge: true` kullanmak,
      // doküman olmasa bile işlemi güvenli hale getirir.
      // Doküman varsa sadece fcmToken alanını günceller,
      // yoksa yeni dokümanı bu alanla oluşturur.
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
        if (kDebugMode) {
          print("FCM token successfully saved/updated for user: ${user.uid}");
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error saving FCM token with set/merge: $e");
        }
      }
    } else {
      if (kDebugMode) {
        print("User not logged in, cannot save FCM token.");
      }
    }
  }
}
