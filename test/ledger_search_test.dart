import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/core/dates/local_date.dart';
import 'package:pacta/features/ledger/domain/entry_search.dart';
import 'package:pacta/features/ledger/domain/models.dart';
import 'package:pacta/features/ledger/presentation/ledger_page.dart';

import 'v2_screens_test.dart' show FakeRepo, app, phoneSize;

/// Gökhan (a) tarafından girilen kayıt; [i] büyüdükçe daha eski.
LedgerEntry entry(
  int i, {
  String description = '',
  int amountMinor = 1000,
  String asset = 'TRY',
  String kind = 'debt',
  String direction = 'aToB',
  String state = 'confirmed',
  String? awaitingSide,
}) => LedgerEntry.fromMap('e-$i', {
  'ledgerId': 'p_can',
  'kind': kind,
  'direction': direction,
  'asset': asset,
  'amountMinor': amountMinor,
  'deltaMinor': direction == 'aToB' ? amountMinor : -amountMinor,
  'occurredOn': const LocalDate(2026, 9, 20).addDays(-i).toIso(),
  'description': description,
  'state': state,
  'version': 1,
  'proposedBy': 'a',
  'awaitingSide': ?awaitingSide,
  'createdAt': Timestamp.fromDate(
    DateTime(2026, 9, 20).subtract(Duration(hours: i)),
  ),
});

void main() {
  setUpAll(() async {
    PactaTheme.useGoogleFonts = false;
    await initializeDateFormatting('tr_TR');
  });

  group('eşleşme', () {
    bool hit(LedgerEntry e, String q, {Side me = Side.a}) =>
        searchEntries([e], me, q).isNotEmpty;

    test('boş sorgu her kaydı tutar', () {
      final e = entry(1, description: 'Kira');
      expect(entrySearchTerms('   '), isEmpty);
      expect(hit(e, ''), isTrue);
      expect(hit(e, '  '), isTrue);
    });

    test('Türkçe büyük-küçük harf: İ/i ve I/ı', () {
      final kira = entry(1, description: 'İSTANBUL KİRA');
      expect(hit(kira, 'istanbul kira'), isTrue);
      expect(hit(kira, 'İstanbul'), isTrue);
      final isik = entry(2, description: 'ışık faturası');
      expect(hit(isik, 'IŞIK'), isTrue);
      expect(hit(isik, 'FATURASI'), isTrue);
      // "I" Türkçede "ı"dır; "isik" farklı bir kelime.
      expect(hit(isik, 'isik'), isFalse);
    });

    test('tutar: ekrandaki biçim ve yazıldığı gibi', () {
      final big = entry(1, amountMinor: 125000); // 1.250,00 ₺
      expect(hit(big, '250'), isTrue);
      expect(hit(big, '1250'), isTrue);
      expect(hit(big, '1.250'), isTrue);
      expect(hit(big, '1.250,00 ₺'), isTrue);
      expect(hit(big, '12,5'), isFalse);
      final small = entry(2, amountMinor: 1250); // 12,50 ₺
      expect(hit(small, '12,5'), isTrue);
      expect(hit(small, '12.5'), isTrue);
      expect(hit(small, '250'), isFalse);
    });

    test('birim adı da aranır', () {
      final gold = entry(1, asset: 'GAU', amountMinor: 1500); // 1,500 gr
      expect(hit(gold, 'altın'), isTrue);
      expect(hit(gold, '1,5'), isTrue);
      expect(hit(entry(2), 'altın'), isFalse);
    });

    test('başlık ve durum metni', () {
      final waiting = entry(
        1,
        state: 'pending',
        awaitingSide: 'b',
        description: 'Market',
      );
      expect(hit(waiting, 'borç verdiniz'), isTrue);
      expect(hit(waiting, 'onayı bekleniyor'), isTrue);
      expect(hit(waiting, 'onaylı'), isFalse);
      // Karşı tarafın gözünden aynı kayıt.
      expect(hit(waiting, 'borç aldınız', me: Side.b), isTrue);
      expect(hit(waiting, 'onayınız', me: Side.b), isTrue);

      final paid = entry(2, kind: 'payment', direction: 'bToA');
      expect(hit(paid, 'ödeme aldınız'), isTrue);
      expect(hit(paid, 'ONAYLI'), isTrue);
    });

    test('her kelime bir yerde geçmeli', () {
      final e = entry(1, description: 'Kira', amountMinor: 25000);
      expect(hit(e, 'kira 250'), isTrue);
      expect(hit(e, 'kira onaylı'), isTrue);
      expect(hit(e, 'kira 999'), isFalse);
    });
  });

  group('defter sayfası', () {
    testWidgets('sayfalanmış listede görünmeyen eski kayıt da bulunur', (
      tester,
    ) async {
      phoneSize(tester);
      final all = [
        for (var i = 0; i < 119; i++) entry(i, description: 'Kayıt $i'),
        entry(119, description: 'İSTANBUL bileti', amountMinor: 125000),
      ];
      await tester.pumpWidget(
        app(
          const LedgerPage(ledgerId: 'p_can'),
          FakeRepo(),
          entries: {'p_can': all},
        ),
      );
      await tester.pumpAndSettle();
      // İlk 100 kayıt çizilir; en eskisi "daha eski" arkasında.
      final more = find.text('Daha eski kayıtlar (20)');
      await tester.scrollUntilVisible(more, 600);
      expect(find.textContaining('İSTANBUL'), findsNothing);

      await tester.tap(find.byTooltip('Kayıtlarda ara'));
      await tester.pumpAndSettle();
      expect(find.text('Kayıtlarda arayın'), findsOneWidget);
      expect(find.text('Onaylı bakiye'), findsNothing);
      // Başlıkta ad yok; kutunun ipucunda kiminle olduğu yazar.
      expect(find.text('Can Demir ile kayıtlarda ara'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'istanbul');
      await tester.pumpAndSettle();
      expect(find.text('Borç verdiniz · İSTANBUL bileti'), findsOneWidget);
      expect(find.text('1 kayıt bulundu'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1250');
      await tester.pumpAndSettle();
      expect(find.text('Borç verdiniz · İSTANBUL bileti'), findsOneWidget);

      // Aramadan çıkınca sayfalanmış liste geri gelir.
      await tester.tap(find.byTooltip('Aramayı kapat'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Onaylı bakiye'), findsOneWidget);
      await tester.scrollUntilVisible(more, 600);
      expect(find.textContaining('İSTANBUL'), findsNothing);
    });

    testWidgets('sonuç yoksa boş durum; temizle ve kapat', (tester) async {
      phoneSize(tester);
      final all = [
        for (var i = 0; i < 3; i++) entry(i, description: 'Kayıt $i'),
      ];
      await tester.pumpWidget(
        app(
          const LedgerPage(ledgerId: 'p_can'),
          FakeRepo(),
          entries: {'p_can': all},
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kayıtlarda ara'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'kayıt');
      await tester.pumpAndSettle();
      expect(find.text('3 kayıt bulundu'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'kayıt 9');
      await tester.pumpAndSettle();
      expect(find.text('Sonuç yok'), findsOneWidget);
      expect(find.textContaining('kayıt bulundu'), findsNothing);

      // Temizle düğmesi sorguyu siler, arama açık kalır.
      await tester.tap(find.byTooltip('Aramayı temizle'));
      await tester.pumpAndSettle();
      expect(find.text('Kayıtlarda arayın'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'yok böyle');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Aramayı kapat'));
      await tester.pumpAndSettle();
      expect(find.text('Onaylı bakiye'), findsOneWidget);
      expect(find.text('Borç verdiniz · Kayıt 0'), findsOneWidget);
    });

    testWidgets('geri tuşu önce aramayı kapatır, sonra sayfayı', (
      tester,
    ) async {
      phoneSize(tester);
      final all = [entry(0, description: 'Kira')];
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LedgerPage(ledgerId: 'p_can'),
                  ),
                ),
                child: const Text('Defteri aç'),
              ),
            ),
          ),
          FakeRepo(),
          entries: {'p_can': all},
        ),
      );
      await tester.tap(find.text('Defteri aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kayıtlarda ara'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'kira');
      await tester.pumpAndSettle();
      expect(find.text('1 kayıt bulundu'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Onaylı bakiye'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Defteri aç'), findsOneWidget);
    });
  });
}
