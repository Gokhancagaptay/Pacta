import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // firebase_core paketini import et
import 'firebase_options.dart'; // flutterfire configure ile oluşturulan dosya
import 'package:pacta/auth_wrapper.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pacta/services/push_notification_service.dart';

// Uygulamayı çalıştırmadan önce Firebase'i başlatmak için main fonksiyonunu async yapıyoruz
Future<void> main() async {
  // Flutter binding'lerinin (arayüz ve servisler arası bağ) hazır olduğundan emin ol
  WidgetsFlutterBinding.ensureInitialized();

  // Türkçe tarih formatı için gerekli
  await initializeDateFormatting('tr_TR', null);

  // Firebase'i başlat
  // Bu satır, firebase_options.dart dosyasındaki platforma özel ayarları kullanır
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationService().initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
      } else if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.dark;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pacta',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      home: Stack(
        children: [
          const AuthWrapper(),
          Positioned(
            right: 16,
            bottom: 32,
            child: FloatingActionButton(
              onPressed: _toggleTheme,
              child: const Icon(Icons.brightness_6),
              tooltip: 'Tema Değiştir',
            ),
          ),
        ],
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
