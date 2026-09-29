import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/app/app_lock.dart';
import 'package:pacta/app/navigation.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/auth_wrapper.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:pacta/core/report.dart';
import 'package:pacta/firebase_options.dart';
import 'package:pacta/providers/theme_provider.dart';
import 'package:pacta/services/app_link_service.dart';
import 'package:pacta/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Yazı tipi uygulamanın içinden yüklenir; cihaz Google Fonts'a bağlanmaz.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
  await initializeDateFormatting('tr_TR', null);
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // AuthWrapper bağlantı hatası ekranını gösterir ve yeniden dener.
    debugPrint('Firebase başlatılamadı: $e');
  }

  // Çökme raporları (Crashlytics): yalnızca desteklenen platformlarda ve
  // yayın sürümünde. Kullanıcı kimliği eklenmez. Uygulamayı kapatmayan
  // hatalar "ölümcül değil" kaydedilir (çökmesiz oturum oranı doğru kalsın).
  const crashPlatforms = {
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  };
  if (Firebase.apps.isNotEmpty &&
      !kIsWeb &&
      crashPlatforms.contains(defaultTargetPlatform)) {
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

  // Uygulama hemen açılır; bildirim ve link servisleri (izin sorusu, ağ)
  // açılışı bekletmez. İnternet yokken de açılış takılmaz.
  // Kilit ayarı önceden okunur: kilit açıksa uygulama ilk karesinden
  // itibaren kilitli açılır (içerik bir an bile görünmez).
  final lockEnabled = await AppLockController.readEnabled();
  runApp(
    ProviderScope(
      overrides: [
        appLockInitiallyEnabledProvider.overrideWithValue(lockEnabled),
      ],
      child: const MyApp(),
    ),
  );

  if (Firebase.apps.isNotEmpty) {
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
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
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
                'Bu ekran açılamadı. Uygulamayı kapatıp yeniden açın.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
        return AppLockGate(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
