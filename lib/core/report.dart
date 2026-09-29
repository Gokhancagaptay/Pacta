import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Uygulamayı durdurmayan ama bilinmesi gereken hata (bozuk belge, profil
/// tamamlanamadı, bildirim anahtarı kaydedilemedi...). Yayın sürümünde
/// Crashlytics'e "ölümcül değil" olarak gider; kişisel veri eklenmez.
/// Firebase yoksa (testler, web) yalnızca konsola yazılır.
void reportError(Object error, StackTrace? stack, {String? reason}) {
  debugPrint('${reason ?? 'Hata'}: $error');
  if (kIsWeb || Firebase.apps.isEmpty) return;
  const platforms = {TargetPlatform.android, TargetPlatform.iOS};
  if (!platforms.contains(defaultTargetPlatform)) return;
  try {
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: reason,
      fatal: false,
    );
  } catch (_) {
    // Raporlama hatası uygulamayı etkilemez.
  }
}
