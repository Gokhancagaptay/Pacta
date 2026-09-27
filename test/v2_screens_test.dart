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
import 'package:pacta/features/ledger/domain/reminder.dart';
import 'package:pacta/features/ledger/presentation/entry_composer_page.dart';
import 'package:pacta/features/ledger/presentation/home_shell.dart';
import 'package:pacta/features/ledger/presentation/ledger_page.dart';
import 'package:pacta/features/profile/delete_account_page.dart';
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
  Future<AddedPerson> addByEmail(String email) async {
    calls.add('addByEmail $email');
    throw const LedgerException(
      'Bu kişi hesabını açmış ama e-posta adresini henüz doğrulamamış.',
    );
  }

  @override
  Future<({bool self, String name})> previewCode(String code) async {
    calls.add('preview $code');
    return (self: false, name: 'Ece Kaya');
  }

  @override
  Future<AddedPerson> addByCode(String code) async {
    calls.add('addByCode $code');
    return const AddedPerson(
      ledgerId: 'p_ece',
      name: 'Ece Kaya',
      created: true,
    );
  }

  @override
  Future<void> setFavorite(String uid, String ledgerId, bool favorite) async {
    calls.add('favorite $ledgerId $favorite');
  }

  @override
  Future<void> deleteAccount() async {
    calls.add('deleteAccount');
    final error = deleteError;
    if (error != null) throw error;
  }

  /// Verilirse deleteAccount bu hatayı fırlatır (bağlantı koptu vb.).
  LedgerException? deleteError;

  @override
  Future<ConvertResult> convertPrivateLedger(
    String ledgerId, {
    String? email,
    String? code,
    bool includeDescriptions = false,
  }) async {
    calls.add('convert $ledgerId $email $code $includeDescriptions');
    return const ConvertResult(
      ledgerId: 'p_ayse',
      name: 'Ayşe Yılmaz',
      transferred: 2,
      pending: 2,
    );
  }

  @override
  Future<ReminderResult> sendReminder(String ledgerId) async {
    calls.add('remind $ledgerId');
    return const ReminderResult(
      kind: ReminderKind.overdue,
      queued: false,
      nextOn: LocalDate(2026, 9, 28),
    );
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

const today = LocalDate(2026, 9, 25);

Ledger ledger(
  String id,
  String otherUid,
  String otherName,
  int tryBalance, {
  List<Map<String, Object?>> due = const [],
}) => Ledger.fromMap(id, {
  'mode': 'shared',
  'sides': {
    'a': {'uid': 'gokhan', 'displayName': 'Gökhan', 'email': 'g@example.com'},
    'b': {
      'uid': otherUid,
      'displayName': otherName,
      'email': '$otherUid@example.com',
    },
  },
  'balances': {'TRY': tryBalance},
  'pendingCount': 0,
  'dueItems': due,
});

// Ayşe'nin vadesi 5 gün geçmiş 500 ₺'si var; Gökhan, Deniz'e 3 gün sonra
// 750 ₺ ödeyecek.
final ledgers = [
  ledger(
    'p_ayse',
    'ayse',
    'Ayşe Yılmaz',
    120000,
    due: [
      {
        'entryId': 'e-ayse',
        'asset': 'TRY',
        'debtorSide': 'b',
        'openMinor': 50000,
        'dueOn': '2026-09-20',
        'description': 'Kira payı',
      },
    ],
  ),
  ledger('p_can', 'can', 'Can Demir', 200000),
  ledger(
    'p_deniz',
    'deniz',
    'Deniz Aksoy',
    -75000,
    due: [
      {
        'entryId': 'e-deniz',
        'asset': 'TRY',
        'debtorSide': 'a',
        'openMinor': 75000,
        'dueOn': '2026-09-28',
        'description': 'Tatil',
      },
    ],
  ),
];

// Karşı tarafın hesabını sildiği, kapalı defter (listelere eklenmez).
final closedLedger = Ledger.fromMap('p_eski', {
  'mode': 'shared',
  'status': 'closed',
  'sides': {
    'a': {'uid': 'gokhan', 'displayName': 'Gökhan'},
    'b': {'uid': 'eski', 'displayName': 'Silinmiş kullanıcı', 'deleted': true},
  },
  'balances': {'TRY': 30000},
  'pendingCount': 0,
});

// Uygulaması olmayan Bakkal Ahmet: 300 ₺'si 1 Ekim vadeli, toplam 800 ₺.
final privateLedger = Ledger.fromMap('v_bakkal', {
  'mode': 'private',
  'sides': {
    'a': {'uid': 'gokhan', 'displayName': 'Gökhan'},
    'b': {'uid': null, 'displayName': 'Bakkal Ahmet'},
  },
  'balances': {'TRY': 80000},
  'pendingCount': 0,
  'dueItems': [
    {
      'entryId': 'e-bakkal',
      'asset': 'TRY',
      'debtorSide': 'b',
      'openMinor': 30000,
      'dueOn': '2026-10-01',
      'description': 'Veresiye',
    },
  ],
});

// Ayşe'yle ortak deftere taşınmış eski özel defter: listelere ve
// toplamlara girmez, yalnızca arşivden açılır.
final archivedLedger = Ledger.fromMap('v_arsiv', {
  'mode': 'private',
  'status': 'closed',
  'convertedTo': 'p_ayse',
  'sides': {
    'a': {'uid': 'gokhan', 'displayName': 'Gökhan'},
    'b': {'uid': null, 'displayName': 'Ayşe (eski)'},
  },
  'balances': {'TRY': 99900},
  'pendingCount': 0,
});

final recent = [
  LedgerEntry.fromMap('e-can', {
    'ledgerId': 'p_can',
    'kind': 'debt',
    'direction': 'aToB',
    'asset': 'TRY',
    'amountMinor': 200000,
    'deltaMinor': 200000,
    'occurredOn': '2026-09-24',
    'description': 'Telefon',
    'state': 'confirmed',
    'version': 1,
    'proposedBy': 'a',
  }),
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
    ledgersProvider.overrideWith(
      (ref) => Stream.value([...ledgers, archivedLedger]),
    ),
    inboxProvider.overrideWith((ref) => Stream.value(inbox)),
    notificationsProvider.overrideWith((ref) => Stream.value(const [])),
    recentEntriesProvider.overrideWith((ref) => Stream.value(recent)),
    todayProvider.overrideWith((ref) => today),
    ledgerProvider.overrideWith(
      (ref, id) => Stream.value(
        [
          ...ledgers,
          closedLedger,
          privateLedger,
          archivedLedger,
        ].firstWhere((l) => l.id == id),
      ),
    ),
    entriesProvider.overrideWith((ref, id) => Stream.value(const [])),
    userProfileProvider.overrideWith(
      (ref) => Stream.value(
        UserModel(
          uid: 'gokhan',
          email: 'g@example.com',
          adSoyad: 'Gökhan Ç',
          favoriteLedgers: const {'p_deniz'},
        ),
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

  testWidgets(
    'ana sayfa onaylı bakiyeyi, bekleyen onayı ve vadeleri gösterir',
    (tester) async {
      phoneSize(tester);
      final repo = FakeRepo();
      await tester.pumpWidget(app(const HomeShell(), repo));
      await tester.pumpAndSettle();

      expect(find.text('Gökhan'), findsOneWidget);
      expect(find.text('+2.450,00 ₺'), findsOneWidget);
      expect(find.text('3.200,00 ₺'), findsOneWidget);
      expect(find.text('Mert Kaya size borç yazdı'), findsOneWidget);
      expect(find.text('Yaklaşan vadeler'), findsOneWidget);
      expect(find.text('Alacağınız · Kira payı · 5 gün geçti'), findsOneWidget);
      expect(find.text('Ödeyeceğiniz · Tatil · 3 gün sonra'), findsOneWidget);
      // Kişi listesinde vade durumu satır altında.
      expect(find.text('Vadesi geçti · 20 Eylül'), findsOneWidget);
    },
  );

  testWidgets('Hareketler: onay doğru sürümle gönderilir', (tester) async {
    phoneSize(tester);
    final repo = FakeRepo();
    await tester.pumpWidget(app(const HomeShell(), repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hareketler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Onayla'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['confirm p_mert/e-mert v2']);
    expect(find.text('Onaylandı. Bakiyenize işlendi.'), findsOneWidget);
  });

  testWidgets('Hareketler: vadeler ayrılır, geçmiş tüm defterlerden gelir', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(app(const HomeShell(), FakeRepo()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hareketler').last);
    await tester.pumpAndSettle();

    expect(find.text('Vadesi geçenler'), findsOneWidget);
    expect(find.text('Önümüzdeki 30 gün'), findsOneWidget);
    expect(find.text('Tahsil edilecek'), findsOneWidget);

    await tester.tap(find.text('Geçmiş'));
    await tester.pumpAndSettle();
    expect(find.text('Borç verdiniz · Telefon'), findsOneWidget);
    expect(find.text('Can Demir'), findsWidgets);
  });

  testWidgets('Kişiler: tablo, toplam ve vadesi geçen süzgeci', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(app(const HomeShell(), FakeRepo()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kişiler').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tablo görünümü'));
    await tester.pumpAndSettle();
    expect(find.text('Bakiye'), findsOneWidget);
    expect(find.text('Toplam'), findsOneWidget);
    expect(
      find.text('+2.450,00 ₺'),
      findsNWidgets(2),
    ); // özet kartı + toplam satırı
    expect(find.text('20 Eyl'), findsOneWidget);

    await tester.tap(find.text('Vadesi geçen (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('Can Demir'), findsNothing);
  });

  Future<FakeRepo> openAddSheet(WidgetTester tester) async {
    phoneSize(tester);
    final repo = FakeRepo();
    await tester.pumpWidget(app(const HomeShell(), repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kişiler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kişi ekle'));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('Kişi ekle: e-postayla eklenemezse nedeni panelde yazar', (
    tester,
  ) async {
    final repo = await openAddSheet(tester);
    expect(find.text('QR okut'), findsOneWidget);
    expect(find.text('Kodumu göster'), findsOneWidget);
    expect(find.text('Davet et'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'E-posta ya da Pacta kodu'),
      'ece@example.com',
    );
    await tester.tap(find.text('Bul ve ekle'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['addByEmail ece@example.com']);
    expect(find.textContaining('doğrulamamış'), findsOneWidget);
    expect(find.text('Kişi ekle'), findsWidgets); // panel açık kaldı
  });

  testWidgets('Kişi ekle: kodla bulunan kişi onaylanıp eklenir', (
    tester,
  ) async {
    final repo = await openAddSheet(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'E-posta ya da Pacta kodu'),
      'k7q-3xm',
    );
    await tester.tap(find.text('Bul ve ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Ece Kaya'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['preview K7Q3XM', 'addByCode K7Q3XM']);
    expect(find.text('Ece Kaya eklendi.'), findsOneWidget);
  });

  testWidgets('Kişiler: e-posta ve favori görünür, basılı tutunca eylemler', (
    tester,
  ) async {
    phoneSize(tester);
    final repo = FakeRepo();
    await tester.pumpWidget(app(const HomeShell(), repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kişiler').last);
    await tester.pumpAndSettle();

    expect(find.text('ayse@example.com'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget); // Deniz favori

    await tester.longPress(find.text('Can Demir').last);
    await tester.pumpAndSettle();
    expect(find.text('Listeden kaldır'), findsOneWidget);
    await tester.tap(find.text('Favorilere ekle'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['favorite p_can true']);

    // Listeden kaldırma onay ister; açık bakiye uyarısı gösterilir.
    await tester.longPress(find.text('Can Demir').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listeden kaldır'));
    await tester.pumpAndSettle();
    expect(find.text('Listeden kaldırılsın mı?'), findsOneWidget);
    expect(find.textContaining('açık bakiye'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
  });

  testWidgets('Kapalı defter: açıklama görünür, yeni kayıt eklenemez', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(const LedgerPage(ledgerId: 'p_eski'), FakeRepo()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Silinmiş kullanıcı'), findsOneWidget);
    expect(find.textContaining('Pacta hesabını sildi'), findsOneWidget);
    expect(find.text('Kayıt ekle'), findsNothing);
    expect(find.text('Hatırlat'), findsNothing);
  });

  testWidgets('Hesap silme: onay ve yeniden giriş olmadan silinmez', (
    tester,
  ) async {
    phoneSize(tester);
    final repo = FakeRepo();
    final reauthAnswers = <String?>['E-posta ya da şifre hatalı.', null];
    var signedOut = false;
    await tester.pumpWidget(
      app(
        DeleteAccountPage(
          passwordUser: true,
          reauthenticate: ({String? password}) async =>
              reauthAnswers.removeAt(0),
          signOut: () async => signedOut = true,
        ),
        repo,
      ),
    );
    await tester.pumpAndSettle();

    // Açıklamalar uzun; düğme sayfanın altında.
    await tester.scrollUntilVisible(
      find.text('Hesabımı kalıcı olarak sil'),
      300,
    );
    final button = find.widgetWithText(
      FilledButton,
      'Hesabımı kalıcı olarak sil',
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.enterText(
      find.widgetWithText(TextField, 'Şifreniz'),
      'yanlis',
    );
    await tester.pumpAndSettle();

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('E-posta ya da şifre hatalı.'), findsOneWidget);
    expect(repo.calls, isEmpty);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repo.calls, ['deleteAccount']);
    expect(signedOut, isTrue);
    expect(find.text('Hesabınız silindi. Görüşmek üzere.'), findsOneWidget);
  });

  Future<void> pumpDeletePage(
    WidgetTester tester,
    FakeRepo repo, {
    required Future<bool> Function() isUserGone,
    required Future<void> Function() signOut,
  }) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(
        DeleteAccountPage(
          passwordUser: true,
          reauthenticate: ({String? password}) async => null,
          signOut: signOut,
          isUserGone: isUserGone,
        ),
        repo,
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Hesabımı kalıcı olarak sil'),
      300,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.enterText(find.widgetWithText(TextField, 'Şifreniz'), 'sifre');
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Hesabımı kalıcı olarak sil'),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Hesap silme: bağlantı koptu ve hesap duruyorsa çıkış yapılmaz', (
    tester,
  ) async {
    final repo = FakeRepo()
      ..deleteError = const LedgerException('Bağlantı kurulamadı.');
    var signedOut = false;
    await pumpDeletePage(
      tester,
      repo,
      isUserGone: () async => false,
      signOut: () async => signedOut = true,
    );
    expect(find.text('Bağlantı kurulamadı.'), findsOneWidget);
    expect(signedOut, isFalse);
  });

  testWidgets('Hesap silme: yanıt kaybolsa da hesap silindiyse çıkış yapılır', (
    tester,
  ) async {
    final repo = FakeRepo()
      ..deleteError = const LedgerException('Bağlantı kurulamadı.');
    var signedOut = false;
    await pumpDeletePage(
      tester,
      repo,
      isUserGone: () async => true,
      signOut: () async => signedOut = true,
    );
    expect(signedOut, isTrue);
    expect(find.text('Hesabınız silindi. Görüşmek üzere.'), findsOneWidget);
  });

  testWidgets('Hatırlat: tutarsız önizleme gösterir ve sunucuya gönderir', (
    tester,
  ) async {
    phoneSize(tester);
    final repo = FakeRepo();
    await tester.pumpWidget(app(const LedgerPage(ledgerId: 'p_ayse'), repo));
    await tester.pumpAndSettle();

    expect(find.text('Vadeler'), findsOneWidget);
    await tester.tap(find.text('Hatırlat'));
    await tester.pumpAndSettle();
    expect(find.text('Vadesi geçmiş kayıt'), findsOneWidget);
    expect(
      find.text(
        'Gökhan ile hesabınızda vadesi geçmiş bir kayıt görünüyor. '
        'Uygun olduğunuzda göz atabilirsiniz.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Aynı kişiye 3 günde bir hatırlatma gönderebilirsiniz.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Hatırlatma gönder'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['remind p_ayse']);
    expect(find.text('Hatırlatma gönderildi.'), findsOneWidget);
  });

  testWidgets('kayıt ekle Türkçe tutarı kuruşa çevirip gönderir', (
    tester,
  ) async {
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
        const EntryComposerPage(
          ledgerId: 'p_ayse',
          initialMode: ComposerMode.received,
        ),
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

  testWidgets(
    'özel defter ortak deftere taşınır; gidecekler önceden gösterilir',
    (tester) async {
      phoneSize(tester);
      final repo = FakeRepo();
      await tester.pumpWidget(
        app(const LedgerPage(ledgerId: 'v_bakkal'), repo),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("Pacta'ya katıldı mı"), findsOneWidget);
      await tester.tap(find.text('Taşı'));
      await tester.pumpAndSettle();

      // Önizleme: 300 ₺ vadeli + 500 ₺ vadesiz; not gönderilmiyor.
      expect(find.text('Önceki kayıtlardan aktarıldı'), findsOneWidget);
      expect(find.text('Önceki kayıtlardan kalan bakiye'), findsOneWidget);
      expect(find.text('Veresiye'), findsNothing);
      expect(find.text('Açıklamaları da gönder'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ayse@example.com');
      await tester.pump();
      final button = find.widgetWithText(FilledButton, 'Ortak deftere taşı');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(
        repo.calls,
        contains('convert v_bakkal ayse@example.com null false'),
      );
      // Ortak deftere geçildi; eski özel kayıtlara bağlantı var.
      expect(find.text('ayse@example.com'), findsOneWidget);
      expect(find.textContaining('2 kayıt onay bekliyor'), findsOneWidget);
    },
  );

  testWidgets(
    'taşınmış özel defter yalnızca okunur, ortak deftere yönlendirir',
    (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(const LedgerPage(ledgerId: 'v_arsiv'), FakeRepo()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ortak deftere taşındı'), findsWidgets);
      expect(find.text('Kayıt ekle'), findsNothing);
      await tester.tap(find.text('Ortak defteri aç'));
      await tester.pumpAndSettle();
      expect(find.text('Özel defterdeki eski kayıtlar'), findsOneWidget);
    },
  );
}
