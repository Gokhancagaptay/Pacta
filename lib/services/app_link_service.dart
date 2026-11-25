import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'notification_routes.dart';

/// Davet linkleri (`https://pacta-76686.web.app/u/KOD`) uygulamayı açınca
/// rotayı ana ekrana iletir. Akış, uygulamayı açan ilk linki de verir;
/// ayrıca getInitialLink okunursa ilk link iki kez işlenir (iki panel açılır).
class AppLinkService {
  AppLinkService._();

  static Future<void> initialize() async {
    AppLinks().uriLinkStream.listen(
      (uri) => NotificationRoutes.open(uri.path),
      onError: (Object e) => debugPrint('Link dinlenemedi: $e'),
    );
  }
}
