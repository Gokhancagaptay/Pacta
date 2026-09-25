import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/core/dates/local_date.dart';
import 'package:pacta/core/money/money.dart';
import 'package:pacta/features/ledger/application/providers.dart';
import 'package:pacta/features/ledger/data/ledger_repository.dart';
import 'package:pacta/features/ledger/domain/models.dart';
import 'package:pacta/features/ledger/presentation/entry_composer_page.dart';
import 'package:pacta/features/ledger/presentation/home_shell.dart';
import 'package:pacta/features/profile/profile_providers.dart';
import 'package:pacta/models/user_model.dart';

/// Komutları kaydeden, Firebase'e dokunmayan depo.
class FakeRepo extends LedgerRepository {
  final calls = <String>[];
  Map<String, Object?>? lastCreate;

  @override
  String newId() => 'test-entry-0001';

  @override
  Future<void> confirmById(String ledgerId, String entryId, int version) async {
    calls.add('confirm $ledgerId/$entryId v$version');
  }

  @override
  Future<EntryState> createEntry({
    required String ledgerId,
    required String entryId,
    required EntryKind kind,
    required bool iGave,
    required Money amount,
    required LocalDate occurredOn,
    LocalDate? dueOn,
    String description = '',
    String? linkedEntryId,
  }) async {
    lastCreate = {
      'ledgerId': ledgerId,
      'entryId': entryId,
      'kind': kind,
      'iGave': iGave,
      'amountMinor': amount.minor,
      'description': description,
      'dueOn': dueOn,
    };
    return EntryState.pending;
  }
}

Ledger ledger(String id, String otherUid, String otherName, int tryBalance) =>
    Ledger.fromMap(id, {
      'mode': 'shared',
      'sides': {
        'a': {'uid': 'gokhan', 'displayName': 'Gökhan'},
        'b': {'uid': otherUid, 'displayName': otherName},
      },
      'balances': {'TRY': tryBalance},
      'pendingCount': 0,
    });

final ledgers = [
  ledger('p_ayse', 'ayse', 'Ayşe Yılmaz', 120000),
  ledger('p_can', 'can', 'Can Demir', 200000),
  ledger('p_deniz', 'deniz', 'Deniz Aksoy', -75000),
];

final inbox = [
  InboxItem.fromMap({
    'type': 'confirmEntry',
    'ledgerId': 'p_mert',
    'entryId': 'e-mert',
    'fromName': 'Mert Kaya',
    'kind': 'debt',
    'asset': 'TRY',
    'amountMinor': 40000,
    'myDeltaMinor': -40000,
    'description': 'Konser bileti',
    'version': 2,
  }),
];

Widget app(Widget home, FakeRepo repo) => ProviderScope(
  overrides: [
    authUserProvider.overrideWith((ref) => Stream.value(null)),
    currentUidProvider.overrideWith((ref) => 'gokhan'),
    ledgerRepositoryProvider.overrideWithValue(repo),
    ledgersProvider.overrideWith((ref) => Stream.value(ledgers)),
    inboxProvider.overrideWith((ref) => Stream.value(inbox)),
    notificationsProvider.overrideWith((ref) => Stream.value(const [])),
    ledgerProvider.overrideWith(
      (ref, id) => Stream.value(ledgers.firstWhere((l) => l.id == id)),
    ),
    userProfileProvider.overrideWith(
      (ref) => Stream.value(
        UserModel(uid: 'gokhan', email: 'g@example.com', adSoyad: 'Gökhan Ç'),
      ),
    ),
  ],
  child: MaterialApp(
    theme: PactaTheme.light,
    locale: const Locale('tr', 'TR'),
    supportedLocales: const [Locale('tr', 'TR')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  ),
);

/// Telefon boyutu (400x1000): uzun ekranların tamamı çizilsin.
void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    PactaTheme.useGoogleFonts = false;
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('ana sayfa onaylı bakiyeyi ve bekleyen onayı gösterir', (tester) async {
    phoneSize(tester);
    final repo = FakeRepo();
    await tester.pumpWidget(app(const HomeShell(), repo));
    await tester.pumpAndSettle();

    expect(find.text('Gökhan'), findsOneWidget);
    expect(find.text('+2.450,00 ₺'), findsOneWidget);
    expect(find.text('3.200,00 ₺'), findsOneWidget);
    expect(find.text('Mert Kaya size borç yazdı'), findsOneWidget);
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('−750,00 ₺'), findsOneWidget);
  });

  testWidgets('gelen kutusunda onay doğru sürümle gönderilir', (tester) async {
    phoneSize(tester);
    final repo = FakeRepo();
    await tester.pumpWidget(app(const HomeShell(), repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gelen kutusu').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Onayla'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['confirm p_mert/e-mert v2']);
    expect(find.text('Onaylandı. Bakiyenize işlendi.'), findsOneWidget);
  });

  testWidgets('kayıt ekle Türkçe tutarı kuruşa çevirip gönderir', (tester) async {
    phoneSize(tester);
    final repo = FakeRepo();
    await tester.pumpWidget(
      app(const EntryComposerPage(ledgerId: 'p_ayse'), repo),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '12,5');
    await tester.enterText(find.widgetWithText(TextField, 'Ne için?'), 'Taksi');
    await tester.pumpAndSettle();
    expect(find.text('Gökhan size 12,50 ₺ borç yazdı.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Onay için gönder'));
    await tester.pumpAndSettle();

    expect(repo.lastCreate, {
      'ledgerId': 'p_ayse',
      'entryId': 'test-entry-0001',
      'kind': EntryKind.debt,
      'iGave': true,
      'amountMinor': 1250,
      'description': 'Taksi',
      'dueOn': null,
    });
  });

  testWidgets('aleyhe kayıt onaysız işleneceğini söyler', (tester) async {
    phoneSize(tester);
    final repo = FakeRepo();
    await tester.pumpWidget(
      app(
        const EntryComposerPage(ledgerId: 'p_ayse', initialMode: ComposerMode.received),
        repo,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '300');
    await tester.pumpAndSettle();

    expect(find.textContaining('onay beklemeden'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();
    expect(repo.lastCreate?['kind'], EntryKind.payment);
    expect(repo.lastCreate?['iGave'], false);
    expect(repo.lastCreate?['amountMinor'], 30000);
  });
}
