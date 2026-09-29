import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';

/// Web'de yayınlanan yasal sayfalar (hosting/gizlilik, hosting/kosullar,
/// hosting/hesap-sil). Metin değişip yeniden kabul gerekiyorsa
/// [AppConstants.termsVersion] artırılır.
enum LegalPage {
  privacy('gizlilik', 'Gizlilik ve KVKK Aydınlatma Metni'),
  terms('kosullar', 'Kullanım Koşulları'),
  accountDeletion('hesap-sil', 'Hesap silme');

  const LegalPage(this.path, this.title);

  final String path;
  final String title;

  Uri get uri => Uri.parse('${AppConstants.webBaseUrl}/$path/');
}

/// Sayfayı uygulama içi tarayıcıda açar; açılamazsa adresi gösterir.
Future<void> openLegalPage(BuildContext context, LegalPage page) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(page.uri, mode: LaunchMode.inAppBrowserView);
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Sayfa açılamadı: ${page.uri}')),
    );
  }
}
