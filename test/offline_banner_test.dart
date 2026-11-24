import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/features/ledger/application/providers.dart';
import 'package:pacta/features/ledger/data/ledger_repository.dart';
import 'package:pacta/features/ledger/presentation/common.dart';
import 'package:pacta/features/ledger/presentation/home_shell.dart';
import 'package:pacta/features/ledger/presentation/offline_banner.dart';

import 'v2_screens_test.dart' show FakeRepo, app, phoneSize;

/// Bağlantı yokken Android eklentisinin ilettiği hata.
class _NoNetwork extends FirebaseFunctionsException {
  _NoNetwork() : super(code: 'unavailable', message: 'UNAVAILABLE');
}

class _OfflineCallable implements HttpsCallable {
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) =>
      Future.error(_NoNetwork());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Her çağrısı bağlantı hatasıyla biten Cloud Functions.
class _OfflineFunctions implements FirebaseFunctions {
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _OfflineCallable();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final band = find.text('$offlineBannerTitle $offlineBannerBody');

/// Yalnızca şerit ve altında bir içerik.
Widget bannerApp(Stream<bool> sync, {double textScale = 1}) => ProviderScope(
  overrides: [serverSyncProvider.overrideWith((ref) => sync)],
  child: MaterialApp(
    theme: PactaTheme.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: const Scaffold(body: OfflineBanner(child: Text('İçerik'))),
      ),
    ),
  ),
);

/// Akışa değer verir ve dinleyicilerin almasını bekler.
Future<void> emit(
  WidgetTester tester,
  StreamController<bool> sync,
  bool synced,
) async {
  sync.add(synced);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    PactaTheme.useGoogleFonts = false;
    await initializeDateFormatting('tr_TR');
  });

  late StreamController<bool> sync;
  setUp(() => sync = StreamController<bool>());
  // Dinlenmemiş akışın close() sonucu hiç tamamlanmaz; beklenmez.
  tearDown(() => unawaited(sync.close()));

  testWidgets('açılışta sunucu verisi beklenirken şerit görünmez', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(const HomeShell(), FakeRepo(), serverSync: sync.stream),
    );
    await emit(tester, sync, false); // ilk veri önbellekten
    await tester.pump(offlineStartGrace - const Duration(seconds: 1));
    expect(band, findsNothing);

    await emit(tester, sync, true); // sunucu yanıtı geldi
    await tester.pump(const Duration(seconds: 30));
    expect(band, findsNothing);
    expect(find.text('Gökhan'), findsOneWidget);
  });

  testWidgets('çevrimdışıyken ana kabukta şerit çıkar, bağlantı gelince '
      'kalkar', (tester) async {
    phoneSize(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      app(const HomeShell(), FakeRepo(), serverSync: sync.stream),
    );
    await emit(tester, sync, false);
    await tester.pump(offlineStartGrace);
    expect(band, findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Çevrimdışısınız. Son bilinen veriler')),
      findsOneWidget,
    );
    // Önbellekteki veri görünmeye devam eder.
    expect(find.text('Gökhan'), findsOneWidget);

    await emit(tester, sync, true);
    await tester.pump(offlineHideAfter);
    expect(band, findsNothing);
    semantics.dispose();
  });

  testWidgets('kısa kopma şerit göstermez; uzun kopmada çıkar, bir an gelen '
      'bağlantı şeridi kaldırmaz', (tester) async {
    await tester.pumpWidget(bannerApp(sync.stream));
    await emit(tester, sync, true);

    // Eşitlendikten sonra 3 saniyeden kısa kopma görünmez.
    await emit(tester, sync, false);
    await tester.pump(offlineShowAfter - const Duration(milliseconds: 500));
    await emit(tester, sync, true);
    await tester.pump(const Duration(seconds: 30));
    expect(band, findsNothing);

    // Uzun kopma: açılış beklemesi değil, kısa süre uygulanır.
    await emit(tester, sync, false);
    await tester.pump(offlineShowAfter);
    expect(band, findsOneWidget);

    // Bağlantı bir an gelip gitti: şerit kalır.
    await emit(tester, sync, true);
    await tester.pump(offlineHideAfter - const Duration(milliseconds: 500));
    expect(band, findsOneWidget);
    await emit(tester, sync, false);
    await tester.pump(const Duration(seconds: 30));
    expect(band, findsOneWidget);

    // Bağlantı kalıcı geldi: şerit kalkar.
    await emit(tester, sync, true);
    await tester.pump(offlineHideAfter);
    expect(band, findsNothing);
  });

  testWidgets('durum bilinmiyorsa (hata, yanıt yok) şerit çıkmaz', (
    tester,
  ) async {
    await tester.pumpWidget(bannerApp(sync.stream));
    await tester.pump(const Duration(seconds: 30));
    expect(band, findsNothing);

    sync.addError(StateError('izin yok'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(band, findsNothing);
  });

  testWidgets('arka planda karar verilmez; dönüşte açılış beklemesi '
      'uygulanır', (tester) async {
    await tester.pumpWidget(bannerApp(sync.stream));
    await emit(tester, sync, true);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await emit(tester, sync, false); // telefon kilitliyken bağlantı kapandı
    await tester.pump(const Duration(minutes: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(offlineShowAfter + const Duration(seconds: 1));
    expect(band, findsNothing); // yeniden bağlanırken bir an yanmaz

    await emit(tester, sync, true);
    await tester.pump(const Duration(seconds: 30));
    expect(band, findsNothing);

    // Gerçekten çevrimdışıysa dönüşten sonra şerit yine çıkar.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await emit(tester, sync, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(offlineStartGrace);
    expect(band, findsOneWidget);
  });

  testWidgets('büyük yazıda ve dar ekranda şerit taşmaz', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(bannerApp(sync.stream, textScale: 2));
    await emit(tester, sync, false);
    await tester.pump(offlineStartGrace);
    expect(band, findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('İçerik'), findsOneWidget);
  });

  test('bağlantı yokken komut hatası kısa ve Türkçe', () async {
    final repo = LedgerRepository(functions: _OfflineFunctions());
    await expectLater(
      repo.confirmById('p_ayse', 'e-1', 1),
      throwsA(
        isA<LedgerException>().having(
          (e) => e.message,
          'message',
          networkErrorMessage,
        ),
      ),
    );
    expect(networkErrorMessage, startsWith('Bağlantı kurulamadı.'));
    // Oturum anahtarı yenilenemeyince gelen İngilizce ağ hatası.
    expect(
      commandMessage(
        'unknown',
        'com.google.firebase.FirebaseNetworkException: A network error '
            '(such as timeout, interrupted connection or unreachable host) '
            'has occurred.',
      ),
      networkErrorMessage,
    );
    expect(
      commandMessage('deadline-exceeded', 'DEADLINE_EXCEEDED'),
      networkErrorMessage,
    );
  });

  testWidgets(
    'bağlantı yokken komut hatası kullanıcıya bu metinle gösterilir',
    (tester) async {
      final repo = LedgerRepository(functions: _OfflineFunctions());
      await tester.pumpWidget(
        MaterialApp(
          theme: PactaTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    runCommand(context, () => repo.confirmById('p', 'e', 1)),
                child: const Text('Onayla'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();
      expect(find.text(networkErrorMessage), findsOneWidget);
      expect(find.textContaining('UNAVAILABLE'), findsNothing);
    },
  );
}
