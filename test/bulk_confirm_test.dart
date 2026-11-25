import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/core/money/asset.dart';
import 'package:pacta/features/ledger/data/ledger_repository.dart';
import 'package:pacta/features/ledger/domain/models.dart';
import 'package:pacta/features/ledger/presentation/activity_page.dart';
import 'package:pacta/features/ledger/presentation/bulk_confirm_sheet.dart';

import 'v2_screens_test.dart' show FakeRepo, app, phoneSize;

InboxItem item(
  String id, {
  String type = 'confirmEntry',
  String asset = 'TRY',
  int myDelta = -40000,
  String from = 'Mert Kaya',
}) => InboxItem.fromMap({
  'type': type,
  'ledgerId': 'p_$id',
  'entryId': 'e-$id',
  'fromName': from,
  'kind': 'debt',
  'asset': asset,
  'amountMinor': myDelta.abs(),
  'myDeltaMinor': myDelta,
  'description': 'Kayıt $id',
  'version': 1,
});

/// Belirli kayıtları onaylayamayan sahte depo.
class FailingRepo extends FakeRepo {
  FailingRepo(this.failing, {this.stale = false});

  final Set<String> failing;
  final bool stale;

  @override
  Future<void> confirmById(String ledgerId, String entryId, int version) async {
    if (failing.contains(entryId)) {
      throw LedgerException(
        'Bu kayıt sizin onayınızı beklemiyor.',
        isStale: stale,
      );
    }
    await super.confirmById(ledgerId, entryId, version);
  }
}

void main() {
  setUpAll(() async {
    PactaTheme.useGoogleFonts = false;
    await initializeDateFormatting('tr_TR');
  });

  group('hesap', () {
    test('düzenleme bekleyenler toplu onaya girmez', () {
      final list = [item('a'), item('b', type: 'reviseEntry'), item('c')];
      expect(bulkConfirmable(list).map((i) => i.entryId), ['e-a', 'e-c']);
    });

    test('etki birim birim toplanır, birimler karışmaz', () {
      final effect = bulkConfirmEffect([
        item('a', myDelta: -40000),
        item('b', myDelta: 15000),
        item('c', asset: 'USD', myDelta: -2500),
        item('d', asset: 'GAU', myDelta: 2000),
        item('e', asset: 'GAU', myDelta: -2000),
      ]);
      expect(effect.map((m) => m.asset), [Asset.tryLira, Asset.usd]);
      expect(effect.map((m) => m.minor), [-25000, -2500]);
    });
  });

  group('pencere', () {
    Future<FakeRepo> open(WidgetTester tester, FakeRepo repo) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showBulkConfirmSheet(context, [
                    item('a', from: 'Mert Kaya', myDelta: -40000),
                    item('b', from: 'Ayşe Yılmaz', myDelta: -10000),
                    item('c', from: 'Deniz Ak', asset: 'USD', myDelta: 500),
                  ]),
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
          repo,
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('başta hiçbir kayıt seçili değil, düğme kapalı', (
      tester,
    ) async {
      final repo = await open(tester, FakeRepo());
      final button = find.widgetWithText(FilledButton, 'Kayıt seçin');
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.textContaining('Bakiyenize etkisi'), findsNothing);
      expect(repo.calls, isEmpty);
    });

    testWidgets('seçilenler onaylanır, etkisi önceden gösterilir', (
      tester,
    ) async {
      final repo = await open(tester, FakeRepo());
      await tester.tap(find.text('Mert Kaya size borç yazdı'));
      await tester.tap(find.textContaining('Deniz Ak'));
      await tester.pump();
      expect(
        find.text('Bakiyenize etkisi: −400,00 ₺, +5,00 \$'),
        findsOneWidget,
      );
      await tester.tap(find.text('2 kaydı onayla'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['confirm p_a/e-a v1', 'confirm p_c/e-c v1']);
      expect(find.text('Toplu onay'), findsNothing);
      expect(
        find.text('2 kayıt onaylandı. Bakiyenize işlendi.'),
        findsOneWidget,
      );
    });

    testWidgets('onaylanamayan kayıt işaretli kalır, pencere açık kalır', (
      tester,
    ) async {
      final repo = await open(tester, FailingRepo({'e-b'}, stale: true));
      await tester.tap(find.text('Tümünü seç (3)'));
      await tester.pump();
      await tester.tap(find.text('3 kaydı onayla'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['confirm p_a/e-a v1', 'confirm p_c/e-c v1']);
      expect(find.text('Toplu onay'), findsOneWidget);
      expect(
        find.text('1 kayıt onaylanamadı; işaretli kaldı.'),
        findsOneWidget,
      );
      expect(
        find.text('Kayıt değişti; açıp yeni hâlini inceleyin.'),
        findsOneWidget,
      );
      expect(find.text('1 kaydı onayla'), findsOneWidget);
    });
  });

  Future<void> pumpActivity(WidgetTester tester, List<InboxItem> inbox) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(const ActivityPage(), FakeRepo(), inboxStream: Stream.value(inbox)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Hareketler: iki onay bekleyende toplu onay önerilir', (
    tester,
  ) async {
    await pumpActivity(tester, [item('a'), item('b')]);
    expect(find.text('Toplu onayla'), findsOneWidget);
  });

  testWidgets('Hareketler: tek onay bekleyende toplu onay yok', (tester) async {
    await pumpActivity(tester, [item('a'), item('b', type: 'reviseEntry')]);
    expect(find.text('Toplu onayla'), findsNothing);
  });
}
