import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/core/legal.dart';
import 'package:pacta/screens/auth/terms_screen.dart';

Widget _app(Widget home) => MaterialApp(theme: PactaTheme.light, home: home);

void main() {
  setUpAll(() => PactaTheme.useGoogleFonts = false);

  testWidgets('kutu işaretlenmeden devam edilemez; kabul kaydedilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var accepted = 0;
    final opened = <LegalPage>[];
    await tester.pumpWidget(
      _app(
        TermsScreen(
          onAccept: () async => accepted++,
          openPage: opened.add,
          onSignOut: () async {},
        ),
      ),
    );

    expect(find.text('Devam etmeden önce'), findsOneWidget);
    await tester.tap(find.text(LegalPage.privacy.title));
    expect(opened, [LegalPage.privacy]);

    final button = find.widgetWithText(FilledButton, 'Kabul et ve devam et');
    await tester.scrollUntilVisible(button, 200);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(accepted, 1);
  });

  testWidgets('kayıt başarısızsa hata gösterilir, ekranda kalınır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        TermsScreen(
          updated: true,
          onAccept: () async => throw Exception('offline'),
          openPage: (_) {},
          onSignOut: () async {},
        ),
      ),
    );

    expect(find.text('Koşullarımız güncellendi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Kabul et ve devam et'), 200);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Kabul et ve devam et'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kaydedilemedi'), findsOneWidget);
  });
}
