import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'notification_routes.dart';

/// Davet linkleri (`https://pacta-76686.web.app/u/KOD`) uygulamayı açınca
/// rotayı ana ekrana iletir.
class AppLinkService {
  AppLinkService._();

  static Future<void> initialize() async {
    final links = AppLinks();
    try {
      final initial = await links.getInitialLink();
      if (initial != null) NotificationRoutes.open(initial.path);
    } catch (e) {
      debugPrint('İlk link okunamadı: $e');
    }
    links.uriLinkStream.listen(
      (uri) => NotificationRoutes.open(uri.path),
      onError: (Object e) => debugPrint('Link dinlenemedi: $e'),
    );
  }
}
