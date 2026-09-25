import 'dart:async';

/// Bildirime dokunulunca açılacak uygulama içi rota (`/l/<defter>` ya da
/// `/l/<defter>/e/<kayıt>`). Uygulama kapalıyken gelen rota, ana ekran
/// hazır olunca [takePending] ile alınır.
class NotificationRoutes {
  NotificationRoutes._();

  static final _controller = StreamController<String>.broadcast();
  static String? _pending;

  static Stream<String> get stream => _controller.stream;

  static void open(String? route) {
    if (route == null || !route.startsWith('/l/')) return;
    if (_controller.hasListener) {
      _controller.add(route);
    } else {
      _pending = route;
    }
  }

  static String? takePending() {
    final route = _pending;
    _pending = null;
    return route;
  }

  /// `/l/<defter>/e/<kayıt>` → (defter, kayıt); kayıt yoksa null.
  static ({String ledgerId, String? entryId})? parse(String route) {
    final match = RegExp(
      r'^/l/([A-Za-z0-9_-]+)(?:/e/([A-Za-z0-9_-]+))?$',
    ).firstMatch(route);
    if (match == null) return null;
    return (ledgerId: match[1]!, entryId: match[2]);
  }
}
