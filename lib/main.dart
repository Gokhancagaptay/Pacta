import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/auth_wrapper.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:pacta/firebase_options.dart';
import 'package:pacta/providers/theme_provider.dart';
import 'package:pacta/services/app_link_service.dart';
import 'package:pacta/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // AuthWrapper bağlantı hatası ekranını gösterir ve yeniden dener.
    debugPrint('Firebase başlatılamadı: $e');
  }

  // Uygulama hemen açılır; bildirim ve link servisleri (izin sorusu, ağ)
  // açılışı bekletmez. İnternet yokken de açılış takılmaz.
  runApp(const ProviderScope(child: MyApp()));

  if (Firebase.apps.isNotEmpty) {
    unawaited(
      PushNotificationService().initialize().catchError(
        (Object e) => debugPrint('Bildirim servisi başlatılamadı: $e'),
      ),
    );
    unawaited(
      AppLinkService.initialize().catchError(
        (Object e) => debugPrint('Link servisi başlatılamadı: $e'),
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      theme: PactaTheme.light,
      darkTheme: PactaTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Bir ekran çizilemezse kırmızı hata yerine anlaşılır bir mesaj.
        ErrorWidget.builder = (details) => const Material(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Bir hata oluştu. Lütfen uygulamayı yeniden başlatın.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
