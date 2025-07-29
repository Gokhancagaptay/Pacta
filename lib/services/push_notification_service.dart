import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Future<void> initialize() async {
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

    // 2. FCM Token'ını Al ve Kaydet
    // Kullanıcı giriş yaptığında bu token'ı almak ve kaydetmek daha mantıklıdır.
    // Bu yüzden bu adımı auth state değişikliklerini dinleyen bir yere taşıyabiliriz.
    // Şimdilik burada bırakıyorum, main.dart'ta çağıracağız.
    final token = await _fcm.getToken();
    print("FCM Token: $token");
    if (token != null) {
      await saveTokenToDatabase(token);
    }

    // Token her yenilendiğinde veritabanını güncelle
    _fcm.onTokenRefresh.listen(saveTokenToDatabase);

    // 3. Arkaplan Mesaj Handler'ını Ayarla
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Uygulama açıkken gelen bildirimleri dinle
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        // Burada kullanıcıya uygulama içi bir bildirim (snackbar, dialog vb.) gösterebilirsiniz.
        // Örneğin:
        // Get.snackbar(message.notification!.title!, message.notification!.body!);
      }
    });
  }

  Future<void> saveTokenToDatabase(String token) async {
    // Giriş yapmış kullanıcının ID'sini al
    User? user = _auth.currentUser;

    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
        });
        print("FCM token successfully saved for user: ${user.uid}");
      } catch (e) {
        print("Error saving FCM token: $e");
        // Eğer doküman henüz yoksa (kullanıcı yeni kaydolduysa vb.)
        // `set` ile `merge:true` kullanarak oluşturabilirsiniz.
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
        print("FCM token successfully set for new user: ${user.uid}");
      }
    } else {
      print("User not logged in, cannot save FCM token.");
    }
  }
}
