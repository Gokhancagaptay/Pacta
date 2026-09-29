import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../core/report.dart';
import 'notification_routes.dart';

/// Push bildirimleri: izin, cihaz anahtarı, ön planda gösterim ve bildirime
/// dokununca ilgili ekranın açılması. Anahtar sunucuya callable ile
/// kaydedilir; sunucu aynı anahtarı başka hesaplardan siler (bkz.
/// functions/src/ledger/devices.ts).
class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  /// Çıkışta FCM anahtarı silinemediyse (internetsiz) sonraki açılışta
  /// tekrar denenir.
  static const _pendingDeleteKey = 'push.pendingTokenDelete';

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: AppConstants.functionsRegion,
  );
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'pacta_default_channel',
    'Genel Bildirimler',
    description: 'Pacta uygulaması için yüksek öncelikli bildirim kanalı',
    importance: Importance.high,
  );

  /// Son kaydedilen (kullanıcı, anahtar); aynısı tekrar gönderilmez.
  String? _savedFor;

  /// Bildirim kimliği; aynı saniyede gelen iki bildirim birbirini ezmez.
  int _nextId = DateTime.now().millisecondsSinceEpoch & 0x3fffffff;

  /// Uygulama açılışını bekletmez: runApp'tan sonra çağrılır.
  Future<void> initialize() async {
    await _retryPendingDelete();
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_pacta'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (r) =>
          NotificationRoutes.open(r.payload),
    );

    // Uygulamayı bildirim açtıysa (yerel ya da FCM) ilgili kayda git.
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      NotificationRoutes.open(launch!.notificationResponse?.payload);
    }
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      NotificationRoutes.open(initial.data['route'] as String?);
    }
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

    FirebaseMessaging.onMessage.listen(_showForeground);
  }

  /// Çıkışta: bu cihazın anahtarı hesaptan silinir ve FCM'de iptal edilir.
  /// İnternet yoksa beklemez; iptal sonraki açılışta tekrar denenir. Anahtar
  /// hesaptan silinemese de sonraki girişte sunucu onu eski hesaptan siler.
  Future<void> forgetDevice({
    Duration wait = const Duration(seconds: 3),
  }) async {
    _savedFor = null;
    String? token;
    try {
      token = await _fcm.getToken().timeout(wait);
    } catch (_) {}
    if (token != null) {
      try {
        await _functions
            .httpsCallable('unregisterPushToken')
            .call<void>({'token': token})
            .timeout(wait);
      } catch (_) {}
    }
    try {
      await _fcm.deleteToken().timeout(wait);
      await _setPendingDelete(false);
    } catch (_) {
      await _setPendingDelete(true);
    }
  }

  Future<void> _retryPendingDelete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_pendingDeleteKey) != true) return;
      await _fcm.deleteToken();
      await prefs.remove(_pendingDeleteKey);
    } catch (_) {
      // İnternet yok: bir sonraki açılışta.
    }
  }

  Future<void> _setPendingDelete(bool pending) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pending) {
        await prefs.setBool(_pendingDeleteKey, true);
      } else {
        await prefs.remove(_pendingDeleteKey);
      }
    } catch (_) {}
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;
    await _local.show(
      _nextId++,
      notif.title ?? 'Bildirim',
      notif.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_stat_pacta',
        ),
      ),
      payload: message.data['route'] as String?,
    );
  }

  Future<void> _saveCurrentToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await _saveToken(token);
    } catch (e, st) {
      reportError(e, st, reason: 'FCM anahtarı alınamadı');
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
      await _functions.httpsCallable('registerPushToken').call<void>({
        'token': token,
      });
    } catch (e, st) {
      _savedFor = null;
      reportError(e, st, reason: 'FCM anahtarı kaydedilemedi');
    }
  }
}
