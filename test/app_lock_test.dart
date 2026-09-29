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

    test('cihazın ekran kilidi kaldırılınca uygulama kilidi kapanır', () async {
      SharedPreferences.setMockInitialValues({
        AppLockController.prefsKey: true,
      });
      final auth = FakeDeviceAuth()..available = false;
      final lock = AppLockController(auth, DateTime.now);
      await lock.load();
      expect(lock.state.locked, isTrue);
      // Doğrulama yapılamaz; kullanıcı kilitli kalmaz, ayar kapanır.
      expect(await lock.unlock(), isTrue);
      expect(lock.state.enabled, isFalse);
      expect(auth.calls, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppLockController.prefsKey), isFalse);
    });

    test('tekdüze saat ileri gider', () {
      final a = monotonicNow();
      final b = monotonicNow();
      expect(b.isBefore(a), isFalse);
    });

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

  Widget app(FakeDeviceAuth auth, {bool signedIn = true, bool? preloaded}) =>
      ProviderScope(
        overrides: [
          deviceAuthProvider.overrideWithValue(auth),
          signedInProvider.overrideWithValue(signedIn),
          if (preloaded != null)
            appLockInitiallyEnabledProvider.overrideWithValue(preloaded),
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

  testWidgets('ayar önceden okunduysa içerik ilk karede bile görünmez', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final auth = FakeDeviceAuth()..results.add(false);
    await tester.pumpWidget(app(auth, preloaded: true));
    // İlk kare: henüz hiçbir eşzamansız iş bitmedi.
    expect(find.text('Pacta kilitli'), findsOneWidget);
    expect(find.text('Bakiyeler'), findsNothing);
    await tester.pumpAndSettle();
  });

  test('çıkışta arka plan sayacı sıfırlanır', () async {
    var now = DateTime(2026, 9, 28, 10);
    final lock = AppLockController(
      FakeDeviceAuth(),
      () => now,
      initiallyEnabled: true,
    );
    await lock.unlock();
    lock.onBackground();
    lock.release();
    now = now.add(const Duration(minutes: 5));
    lock.onForeground();
    expect(lock.state.locked, isFalse);
  });
}
