import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacta/app/app_lock.dart';
import 'package:pacta/app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDeviceAuth implements DeviceAuth {
  bool available = true;

  /// Sırayla verilecek sonuçlar; bitince true.
  final results = <bool>[];
  int calls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return results.isEmpty ? true : results.removeAt(0);
  }
}

void main() {
  setUpAll(() => PactaTheme.useGoogleFonts = false);

  group('AppLockController', () {
    test(
      'açılışta kilitli; 1 dakikadan kısa arka plan tekrar sormaz',
      () async {
        SharedPreferences.setMockInitialValues({
          AppLockController.prefsKey: true,
        });
        var now = DateTime(2026, 9, 27, 10);
        final lock = AppLockController(FakeDeviceAuth(), () => now);
        await lock.load();
        expect(lock.state.locked, isTrue);

        expect(await lock.unlock(), isTrue);
        expect(lock.state.locked, isFalse);

        lock.onBackground();
        now = now.add(const Duration(seconds: 30));
        lock.onForeground();
        expect(lock.state.locked, isFalse);

        lock.onBackground();
        now = now.add(const Duration(minutes: 2));
        lock.onForeground();
        expect(lock.state.locked, isTrue);
      },
    );

    test('kapalıyken hiç kilitlenmez', () async {
      SharedPreferences.setMockInitialValues({});
      var now = DateTime(2026, 9, 27, 10);
      final lock = AppLockController(FakeDeviceAuth(), () => now);
      await lock.load();
      lock.onBackground();
      now = now.add(const Duration(hours: 1));
      lock.onForeground();
      expect(lock.state.locked, isFalse);
    });

    test('açıp kapatmak doğrulama ister; ekran kilidi yoksa açılmaz', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = FakeDeviceAuth()..available = false;
      final lock = AppLockController(auth, DateTime.now);
      expect(await lock.setEnabled(true), contains('ekran kilidi'));
      expect(lock.state.enabled, isFalse);

      auth.available = true;
      expect(await lock.setEnabled(true), isNull);
      expect(lock.state.enabled, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppLockController.prefsKey), isTrue);

      auth.results.add(false);
      expect(await lock.setEnabled(false), contains('Doğrulanamadı'));
      expect(lock.state.enabled, isTrue);
    });
  });

  Widget app(FakeDeviceAuth auth, {bool signedIn = true}) => ProviderScope(
    overrides: [
      deviceAuthProvider.overrideWithValue(auth),
      signedInProvider.overrideWithValue(signedIn),
    ],
    child: MaterialApp(
      theme: PactaTheme.light,
      builder: (context, child) => AppLockGate(child: child!),
      home: const Scaffold(body: Text('Bakiyeler')),
    ),
  );

  testWidgets('kilitliyken içerik gizli; doğrulanınca açılır', (tester) async {
    SharedPreferences.setMockInitialValues({AppLockController.prefsKey: true});
    final auth = FakeDeviceAuth()..results.add(false);
    await tester.pumpWidget(app(auth));
    await tester.pumpAndSettle();

    // Kendiliğinden sorulan ilk doğrulama başarısız.
    expect(auth.calls, 1);
    expect(find.text('Pacta kilitli'), findsOneWidget);
    expect(find.text('Bakiyeler'), findsNothing);
    expect(find.textContaining('Doğrulanamadı'), findsOneWidget);

    await tester.tap(find.text('Kilidi aç'));
    await tester.pumpAndSettle();
    expect(find.text('Pacta kilitli'), findsNothing);
    expect(find.text('Bakiyeler'), findsOneWidget);
  });

  testWidgets('oturum yoksa kilit ekranı çıkmaz', (tester) async {
    SharedPreferences.setMockInitialValues({AppLockController.prefsKey: true});
    final auth = FakeDeviceAuth();
    await tester.pumpWidget(app(auth, signedIn: false));
    await tester.pumpAndSettle();
    expect(find.text('Pacta kilitli'), findsNothing);
    expect(find.text('Bakiyeler'), findsOneWidget);
    expect(auth.calls, 0);
  });
}
