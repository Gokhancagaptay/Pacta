import 'package:flutter/widgets.dart';

/// Uygulamanın kök gezgini. Oturumdaki kişi değişince (çıkış, başka hesapla
/// giriş, hesap başka cihazda silindi) açık sayfalar kapatılır: önceki
/// kişinin defteri yeni ekranın üstünde kalmaz.
final appNavigatorKey = GlobalKey<NavigatorState>();
