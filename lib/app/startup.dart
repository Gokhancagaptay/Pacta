import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../core/report.dart';
import '../services/app_link_service.dart';
import '../services/push_notification_service.dart';

bool _started = false;

/// Firebase'e bağlı servisler: çökme raporları, bildirimler, linkler. Bir
/// kez çalışır. Açılışta Firebase başlatılamazsa (internetsiz ilk açılış)
/// AuthWrapper yeniden denemesi başarılı olunca çağrılır; servisler yine
/// kurulur.
Future<void> startAppServices() async {
  if (_started || Firebase.apps.isEmpty) return;
  _started = true;

  // Çökme raporları yalnızca desteklenen platformlarda ve yayın sürümünde.
  // Kullanıcı kimliği eklenmez. Uygulamayı kapatmayan hatalar "ölümcül
  // değil" kaydedilir (çökmesiz oturum oranı doğru kalsın).
  const crashPlatforms = {
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  };
  if (!kIsWeb && crashPlatforms.contains(defaultTargetPlatform)) {
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
      FlutterError.onError = crashlytics.recordFlutterError;
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack);
        return true;
      };
    } catch (e) {
      debugPrint('Crashlytics başlatılamadı: $e');
    }
  }

  // Açılışı bekletmez (izin sorusu, ağ).
  unawaited(
    PushNotificationService.instance.initialize().catchError(
      (Object e, StackTrace st) =>
          reportError(e, st, reason: 'Bildirim servisi başlatılamadı'),
    ),
  );
  unawaited(
    AppLinkService.initialize().catchError(
      (Object e, StackTrace st) =>
          reportError(e, st, reason: 'Link servisi başlatılamadı'),
    ),
  );
}
