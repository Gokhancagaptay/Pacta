import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:pacta/features/ledger/presentation/statement_export.dart';
import 'package:pacta/features/profile/data_export.dart';
import 'package:pacta/features/profile/data_export_firestore.dart';
import 'package:pacta/features/profile/data_export_ui.dart';
import 'package:pacta/features/profile/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'v2_screens_test.dart' show FakeRepo, app;

Timestamp ts(int day, [int hour = 9]) =>
    Timestamp.fromDate(DateTime.utc(2026, 11, day, hour));

/// Bellekte veri; her okumayı ve kullanılan uid'yi kaydeder.
class FakeSource implements DataExportSource {
  FakeSource({this.failOn, this.failWith});

  final calls = <String>[];

  /// Bu okumada hata fırlatır (ör. 'entries').
  final String? failOn;
  final Object? failWith;

  final profile = <String, dynamic>{
    'uid': 'gokhan',
    'email': 'g@example.com',
    'adSoyad': 'Gökhan Ç',
    'termsVersion': '2026-09-27',
    'termsAcceptedAt': ts(1),
    'hiddenLedgers': {'p_can': ts(3)},
  };

  final ledgerDocs = <RawDoc>[
    (
      id: 'p_ayse',
      data: {
        'mode': 'shared',
        'status': 'active',
        'sides': {
          'a': {'uid': 'ayse', 'displayName': 'Ayşe', 'email': 'a@x.com'},
          'b': {'uid': 'gokhan', 'displayName': 'Gökhan', 'email': 'g@x.com'},
        },
        'memberUids': ['ayse', 'gokhan'],
        'balances': {'TRY': 150000, 'USD': -2500, 'GAU': 1500, 'CEYREK': 2},
        'createdAt': ts(5),
        'dueItems': [
          {
            'entryId': 'e2',
            'asset': 'USD',
            'debtorSide': 'a',
            'openMinor': 2500,
            'dueOn': '2026-12-01',
            'description': '',
          },
        ],
      },
    ),
    (
      id: 'v_bakkal',
      data: {
        'mode': 'private',
        'status': 'active',
        'sides': {
          'a': {'uid': 'gokhan', 'displayName': 'Gökhan'},
          'b': {'uid': null, 'displayName': 'Bakkal'},
        },
        'memberUids': ['gokhan'],
        'balances': <String, dynamic>{},
        'createdAt': ts(2),
      },
    ),
  ];

  final entryDocs = <String, List<RawDoc>>{
    'p_ayse': [
      (
        id: 'e2',
        data: {
          'kind': 'debt',
          'asset': 'USD',
          'amountMinor': 2500,
          'deltaMinor': -2500,
          'createdAt': ts(7),
          'dispute': {'reason': 'amount', 'suggestedAmountMinor': 2000},
        },
      ),
      (
        id: 'e1',
        data: {
          'kind': 'debt',
          'asset': 'TRY',
          'amountMinor': 150000,
          'deltaMinor': 150000,
          'createdAt': ts(6),
        },
      ),
    ],
    'v_bakkal': [],
  };

  final revisionDocs = <String, List<RawDoc>>{
    'p_ayse/e1': [
      (id: '2', data: {'version': 2, 'amountMinor': 150000, 'asset': 'TRY'}),
      (id: '1', data: {'version': 1, 'amountMinor': 100000, 'asset': 'TRY'}),
    ],
    'p_ayse/e2': [
      (id: '1', data: {'version': 1, 'amountMinor': 2500, 'asset': 'USD'}),
    ],
  };

  @override
  AccountInfo? currentAccount() => AccountInfo(
    uid: 'gokhan',
    email: 'g@example.com',
    emailVerified: true,
    methods: const [
      (
        providerId: 'password',
        uid: 'g@example.com',
        email: 'g@example.com',
        displayName: null,
        phoneNumber: null,
      ),
    ],
    createdAt: DateTime.utc(2026, 9, 1, 8),
    lastSignInAt: DateTime.utc(2026, 11, 24, 20),
  );

  Future<T> _read<T>(String what, T value) async {
    calls.add(what);
    if (failOn != null && what.startsWith(failOn!)) {
      throw failWith ?? const DataExportException(dataExportOfflineMessage);
    }
    return value;
  }

  @override
  Future<RawDoc?> userProfile(String uid) =>
      _read('user $uid', (id: uid, data: profile));

  @override
  Future<RawDoc?> publicProfile(String uid) => _read('public $uid', (
    id: uid,
    data: <String, dynamic>{'adSoyad': 'Gökhan Ç'},
  ));

  @override
  Future<List<RawDoc>> ledgers(String uid) => _read('ledgers $uid', ledgerDocs);

  @override
  Future<List<RawDoc>> entries(String ledgerId, String uid) =>
      _read('entries $ledgerId $uid', entryDocs[ledgerId] ?? const []);

  @override
  Future<List<RawDoc>> revisions(String ledgerId, String entryId, String uid) =>
      _read(
        'revisions $ledgerId/$entryId $uid',
        revisionDocs['$ledgerId/$entryId'] ?? const [],
      );

  @override
  Future<List<RawDoc>> events(String ledgerId, String uid) =>
      _read('events $ledgerId $uid', [
        (id: 'ev2', data: {'type': 'confirmed', 'entryId': 'e1', 'at': ts(8)}),
        (id: 'ev1', data: {'type': 'created', 'entryId': 'e1', 'at': ts(6)}),
      ]);

  @override
  Future<List<RawDoc>> inbox(String uid) => _read('inbox $uid', [
    (
      id: 'e2',
      data: {
        'type': 'confirmEntry',
        'asset': 'USD',
        'amountMinor': 2500,
        'myDeltaMinor': 2500,
        'createdAt': ts(7),
      },
    ),
  ]);

  @override
  Future<List<RawDoc>> notifications(String uid) => _read(
    'notifications $uid',
    [
      (id: 'n2', data: {'title': 'Yeni', 'isRead': false, 'createdAt': ts(9)}),
      (id: 'n1', data: {'title': 'Eski', 'isRead': true, 'createdAt': ts(4)}),
    ],
  );
}

Future<Map<String, dynamic>> exportOf(FakeSource source) async {
  final data = await DataExportCollector(source).collect('gokhan');
  final map = buildDataExport(
    data,
    uid: 'gokhan',
    now: DateTime.utc(2026, 11, 25, 18, 30),
  );
  // Dosyaya yazılıp geri okunan hâli (JSON'a çevrilemeyen değer kalmasın).
  return jsonDecode(utf8.decode(encodeDataExport(map))) as Map<String, dynamic>;
}

void main() {
  setUpAll(() async {
    PactaTheme.useGoogleFonts = false;
    await initializeDateFormatting('tr_TR');
  });

  group('JSON biçimi', () {
    test('zaman damgası ISO 8601 UTC, tamsayı ve iç içe alanlar korunur', () {
      final value = jsonValue({
        'b': ts(25, 18),
        'a': 150000,
        'list': [
          ts(1),
          {'x': null, 'y': true},
        ],
        'geo': GeoPoint(41, 29),
      });
      expect(value, {
        'a': 150000,
        'b': '2026-11-25T18:00:00.000Z',
        'geo': {'enlem': 41.0, 'boylam': 29.0},
        'list': [
          '2026-11-01T09:00:00.000Z',
          {'x': null, 'y': true},
        ],
      });
      // Anahtarlar sıralı.
      expect((value! as Map).keys.toList(), ['a', 'b', 'geo', 'list']);
    });

    test('tutarlar: küçük birim aynen kalır, okunur yazım yanına gelir', () {
      final doc = exportDoc((
        id: 'e1',
        data: {
          'asset': 'GAU',
          'amountMinor': 1500,
          'deltaMinor': -1500,
          'dispute': {'suggestedAmountMinor': 1000},
          'version': 2,
        },
      ));
      expect((doc['veri']! as Map)['amountMinor'], 1500);
      expect(doc['okunurTutarlar'], {
        'amountMinor': '1,500 gr',
        'deltaMinor': '−1,500 gr',
        'dispute.suggestedAmountMinor': '1,000 gr',
      });
      // Tutarı olmayan belgede okunur bölüm yok.
      expect(
        exportDoc((id: 'n', data: {'title': 'x'}))
            .containsKey('okunurTutarlar'),
        isFalse,
      );
    });

    test('birden çok birimli defter: hiçbir bakiye kaybolmaz', () {
      final amounts = readableAmounts({
        'balances': {
          'TRY': 150000,
          'USD': -2500,
          'EUR': 0,
          'GAU': 1500,
          'CEYREK': 2,
          'XAG': 7,
        },
        'dueItems': [
          {'asset': 'USD', 'openMinor': 2500},
          {'asset': 'CEYREK', 'openMinor': 1},
        ],
      });
      expect(amounts, {
        'balances.CEYREK': '2 çeyrek',
        'balances.EUR': '0,00 €',
        'balances.GAU': '1,500 gr',
        'balances.TRY': '1.500,00 ₺',
        'balances.USD': r'−25,00 $',
        'balances.XAG': '7 (bilinmeyen birim: XAG)',
        'dueItems[0].openMinor': r'25,00 $',
        'dueItems[1].openMinor': '1 çeyrek',
      });
    });

    test('defter özeti bakiyeyi kullanıcının tarafından yazar', () {
      final summary = ledgerSummary(
        FakeSource().ledgerDocs.first.data,
        'gokhan',
      );
      // Gökhan b tarafında: a'ya göre +1.500 TL, Gökhan'ın borcu.
      expect(summary['sizinTarafiniz'], 'b');
      expect(summary['karsiTaraf'], 'Ayşe');
      expect(summary['tur'], 'Ortak defter');
      expect(summary['bakiyeSizinAcinizdan'], [
        '1.500,00 ₺ borcunuz',
        r'25,00 $ alacağınız',
        '1,500 gr borcunuz',
        '2 çeyrek borcunuz',
      ]);
    });

    test('dosya adı yerel tarihle', () {
      expect(
        dataExportFileName(DateTime(2026, 11, 5, 10)),
        'pacta-verilerim-2026-11-05.json',
      );
    });
  });

  group('dosyanın tamamı', () {
    test('üst düzey bölümler, sayılar ve sürüm bilgisi', () async {
      final out = await exportOf(FakeSource());
      expect(out.keys.toList(), [
        'aciklama',
        'dosyaBilgisi',
        'hesap',
        'profil',
        'herkeseAcikProfil',
        'defterler',
        'gelenKutusu',
        'bildirimler',
        'alanlar',
        'dosyadaOlmayanlar',
      ]);
      expect(out['dosyaBilgisi'], {
        'olusturmaZamani': '2026-11-25T18:30:00.000Z',
        'uygulamaSurumu': AppConstants.appVersion,
        'derlemeNumarasi': AppConstants.buildNumber,
        'kosullarSurumu': AppConstants.termsVersion,
        'belgeSayilari': {
          'defter': 2,
          'kayit': 2,
          'kayitSurumu': 3,
          'olay': 4,
          'gelenKutusu': 1,
          'bildirim': 2,
        },
      });
      final hesap = out['hesap'] as Map;
      expect(hesap['kullaniciKimligi'], 'gokhan');
      expect(hesap['epostaDogrulandi'], true);
      expect(hesap['hesapAcilisZamani'], '2026-09-01T08:00:00.000Z');
      expect(hesap['sonGirisZamani'], '2026-11-24T20:00:00.000Z');
      expect((hesap['girisYontemleri'] as List).single, {
        'yontem': 'E-posta ve şifre',
        'saglayici': 'password',
        'saglayicidakiKimlik': 'g@example.com',
        'eposta': 'g@example.com',
      });
      final profil = (out['profil'] as Map)['veri'] as Map;
      expect(profil['termsAcceptedAt'], '2026-11-01T09:00:00.000Z');
      expect(profil['hiddenLedgers'], {'p_can': '2026-11-03T09:00:00.000Z'});
      expect((out['herkeseAcikProfil'] as Map)['veri'], {
        'adSoyad': 'Gökhan Ç',
      });
    });

    test('defter > kayıt > sürüm ve olaylar, eskiden yeniye', () async {
      final out = await exportOf(FakeSource());
      final ledgers = out['defterler'] as List;
      // Özel defter daha önce açıldı.
      expect([for (final l in ledgers) l['kimlik']], ['v_bakkal', 'p_ayse']);
      final ayse = ledgers[1] as Map;
      expect(ayse.keys.toList(), [
        'kimlik',
        'ozet',
        'veri',
        'okunurTutarlar',
        'kayitlar',
        'olaylar',
      ]);
      expect((ayse['veri'] as Map)['balances'], {
        'CEYREK': 2,
        'GAU': 1500,
        'TRY': 150000,
        'USD': -2500,
      });
      expect((ayse['okunurTutarlar'] as Map).keys, [
        'balances.CEYREK',
        'balances.GAU',
        'balances.TRY',
        'balances.USD',
        'dueItems[0].openMinor',
      ]);
      final entries = ayse['kayitlar'] as List;
      expect([for (final e in entries) e['kimlik']], ['e1', 'e2']);
      final e1 = entries[0] as Map;
      expect((e1['veri'] as Map)['createdAt'], '2026-11-06T09:00:00.000Z');
      expect([for (final r in e1['surumler'] as List) r['kimlik']], ['1', '2']);
      expect(((e1['surumler'] as List)[0] as Map)['okunurTutarlar'], {
        'amountMinor': '1.000,00 ₺',
      });
      final e2 = entries[1] as Map;
      expect(e2['okunurTutarlar'], {
        'amountMinor': r'25,00 $',
        'deltaMinor': r'−25,00 $',
        'dispute.suggestedAmountMinor': r'20,00 $',
      });
      expect(
        [for (final e in ayse['olaylar'] as List) e['kimlik']],
        ['ev1', 'ev2'],
      );
      expect(
        [for (final n in out['bildirimler'] as List) n['kimlik']],
        ['n1', 'n2'],
      );
      expect(((out['gelenKutusu'] as List).single as Map)['okunurTutarlar'], {
        'amountMinor': r'25,00 $',
        'myDeltaMinor': r'25,00 $',
      });
    });

    test('dosyada olmayanlar bölümü ve metin kuralları', () async {
      final out = await exportOf(FakeSource());
      final missing = out['dosyadaOlmayanlar'] as Map;
      expect(missing['aciklama'], contains('Haklarınız'));
      final names = [for (final m in missing['liste'] as List) m['veri']];
      for (final name in [
        'Günlük işlem sayaçları',
        'Bekleyen bildirim kuyruğu',
        'Web onay istekleri',
        'Silinen hesap işareti',
        'Çökme raporları',
        'Sunucu kayıtları',
      ]) {
        expect(names, contains(name));
      }
      for (final m in missing['liste'] as List) {
        expect((m['neden'] as String).isNotEmpty, isTrue);
      }
      final text = jsonEncode(out).toLowerCase();
      for (final word in ['senet', 'ibraname', 'kefil', 'icra', '—']) {
        expect(text.contains(word), isFalse, reason: word);
      }
    });
  });

  group('toplama', () {
    test('her liste okuması uid ile, her kayıt için sürümler okunur', () async {
      final source = FakeSource();
      final progress = <DataExportProgress>[];
      final data = await DataExportCollector(source)
          .collect('gokhan', onProgress: progress.add);
      expect(data.documentCount, 2 + 1 + 2 + 2 + 2 + 3 + 4);
      expect(source.calls.toSet(), {
        'user gokhan',
        'public gokhan',
        'inbox gokhan',
        'notifications gokhan',
        'ledgers gokhan',
        'entries p_ayse gokhan',
        'events p_ayse gokhan',
        'revisions p_ayse/e1 gokhan',
        'revisions p_ayse/e2 gokhan',
        'entries v_bakkal gokhan',
        'events v_bakkal gokhan',
      });
      expect(progress.first.fraction, isNull);
      expect(progress.last.ledgersDone, 2);
      expect(progress.last.fraction, 1);
      expect(progress.last.documents, data.documentCount);
      expect(progress.last.label, 'Defterler: 2 / 2 · 16 belge okundu');
    });

    test('çok kayıtlı defter: eşzamanlı okumada da sıra ve sayı tam', () async {
      final source = FakeSource();
      source.entryDocs['v_bakkal'] = [
        for (var i = 0; i < 50; i++)
          (id: 'k$i', data: <String, dynamic>{'createdAt': ts(10)}),
      ];
      final data = await DataExportCollector(
        source,
        parallel: 4,
      ).collect('gokhan');
      final bakkal = data.ledgers.firstWhere((l) => l.doc.id == 'v_bakkal');
      expect(
        [for (final e in bakkal.entries) e.doc.id],
        [for (var i = 0; i < 50; i++) 'k$i'],
      );
      expect(
        source.calls.where((c) => c.startsWith('revisions v_bakkal')),
        hasLength(50),
      );
    });

    test('hata olduğu gibi iletilir, oturum yoksa okunmaz', () async {
      final source = FakeSource(failOn: 'entries');
      await expectLater(
        DataExportCollector(source).collect('gokhan'),
        throwsA(
          isA<DataExportException>().having(
            (e) => e.message,
            'message',
            dataExportOfflineMessage,
          ),
        ),
      );
      final empty = FakeSource();
      await expectLater(
        DataExportCollector(empty).collect(''),
        throwsA(isA<DataExportException>()),
      );
      expect(empty.calls, isEmpty);
    });

    test('vazgeçilince sonraki adımda durur', () async {
      final source = FakeSource();
      await expectLater(
        DataExportCollector(source).collect('gokhan', isCancelled: () => true),
        throwsA(isA<DataExportCancelled>()),
      );
      expect(source.calls.any((c) => c.startsWith('entries')), isFalse);
    });

    test('Firestore hata kodları Türkçe mesaja çevrilir', () {
      expect(dataExportErrorMessage('unavailable'), dataExportOfflineMessage);
      expect(
        dataExportErrorMessage('permission-denied'),
        startsWith('Verilerinize erişilemedi'),
      );
      expect(
        dataExportErrorMessage('internal'),
        startsWith('Veriler okunamadı'),
      );
    });
  });

  group('Profil > Verilerimi indir', () {
    Future<List<ExportFile>> open(
      WidgetTester tester,
      FakeSource source,
    ) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final sent = <ExportFile>[];
      await tester.pumpWidget(
        app(
          ProviderScope(
            overrides: [
              exportSinkProvider.overrideWithValue((f) async => sent.add(f)),
              dataExportSourceProvider.overrideWithValue(source),
            ],
            child: const ProfilePage(),
          ),
          FakeRepo(),
        ),
      );
      await tester.pumpAndSettle();
      final item = find.text('Verilerimi indir');
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pumpAndSettle();
      return sent;
    }

    testWidgets('açıklama gösterilir; vazgeçilince hiçbir şey okunmaz', (
      tester,
    ) async {
      final source = FakeSource();
      final sent = await open(tester, source);
      expect(find.text('Dosyayı hazırla'), findsOneWidget);
      expect(
        find.textContaining('karşı tarafın adı ve e-postası'),
        findsOneWidget,
      );
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(find.text('Dosyayı hazırla'), findsNothing);
      expect(source.calls, isEmpty);
      expect(sent, isEmpty);
    });

    testWidgets('dosya hazırlanır ve paylaşıma JSON olarak gider', (
      tester,
    ) async {
      final source = FakeSource();
      final sent = await open(tester, source);
      await tester.tap(find.text('Dosyayı hazırla'));
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      final f = sent.single;
      expect(f.mime, 'application/json');
      expect(f.name, startsWith('pacta-verilerim-'));
      expect(f.name, endsWith('.json'));
      expect(f.subject, 'Pacta verilerim');
      final out = jsonDecode(utf8.decode(f.bytes)) as Map<String, dynamic>;
      expect((out['defterler'] as List), hasLength(2));
      expect(find.text('Verileriniz hazırlanıyor'), findsNothing);
    });

    testWidgets('bağlantı yoksa açık bir mesaj, dosya gönderilmez', (
      tester,
    ) async {
      final source = FakeSource(failOn: 'user');
      final sent = await open(tester, source);
      await tester.tap(find.text('Dosyayı hazırla'));
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      expect(find.text(dataExportOfflineMessage), findsOneWidget);
    });
  });
}
