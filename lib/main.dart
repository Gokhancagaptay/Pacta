import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/app/app_lock.dart';
import 'package:pacta/app/navigation.dart';
import 'package:pacta/app/startup.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/auth_wrapper.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:pacta/firebase_options.dart';
import 'package:pacta/providers/theme_provider.dart';

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

  // Yayın sürümünde bir ekran çizilemezse kırmızı hata yerine anlaşılır
  // mesaj; geliştirmede asıl hata görünür.
  if (kReleaseMode) {
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
  }

  // Uygulama hemen açılır; bildirim ve link servisleri (izin sorusu, ağ)
  // açılışı bekletmez. İnternet yokken de açılış takılmaz.
  // Kilit ayarı önceden okunur: kilit açıksa uygulama ilk karesinden
  // itibaren kilitli açılır (içerik bir an bile görünmez).
  final lockEnabled = await AppLockController.readEnabled();
  // Tema da önceden okunur: kayıtlı koyu tema ilk karede açık görünmesin.
  final theme = await ThemeNotifier.readSaved();
  runApp(
    ProviderScope(
      overrides: [
        appLockInitiallyEnabledProvider.overrideWithValue(lockEnabled),
        initialThemeProvider.overrideWithValue(theme),
      ],
      child: const MyApp(),
    ),
  );

  unawaited(startAppServices());
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
      builder: (context, child) =>
          AppLockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
