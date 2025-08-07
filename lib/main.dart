import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/auth_wrapper.dart';
import 'package:pacta/firebase_options.dart';
import 'package:pacta/providers/theme_provider.dart';
import 'package:pacta/services/push_notification_service.dart';
import 'package:pacta/theme/app_theme.dart';
import 'package:pacta/constants/app_constants.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize services sequentially
    await initializeDateFormatting('tr_TR', null);
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await PushNotificationService().initialize();

    // Setup global error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // In production, you might want to send this to a crash reporting service
      print('Flutter Error: ${details.exception}');
    };

    runApp(const ProviderScope(child: MyApp()));
  } catch (error, stackTrace) {
    print('Error during app initialization: $error');
    print('Stack trace: $stackTrace');

    // Fallback: run app without some features
    runApp(const ProviderScope(child: MyApp()));
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
      // Error handling for widget errors
      builder: (context, widget) {
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return _buildErrorWidget(errorDetails);
        };
        return widget ?? const SizedBox.shrink();
      },
    );
  }

  /// Custom error widget for better user experience
  Widget _buildErrorWidget(FlutterErrorDetails errorDetails) {
    return Material(
      child: Container(
        color: Colors.red.shade50,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Bir hata oluştu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lütfen uygulamayı yeniden başlatın.',
                  style: TextStyle(fontSize: 14, color: Colors.red.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
