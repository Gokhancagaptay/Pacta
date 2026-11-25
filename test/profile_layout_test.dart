import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/features/profile/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'v2_screens_test.dart' show FakeRepo, app;

void main() {
  setUpAll(() async {
    PactaTheme.useGoogleFonts = false;
    await initializeDateFormatting('tr_TR');
  });

  Future<void> pumpProfile(
    WidgetTester tester, {
    required double width,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width * 3, 2400);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app(const ProfilePage(), FakeRepo()));
    await tester.pumpAndSettle();
  }

  double rowTop(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('geniş ekranda tema seçici başlıkla aynı satırda', (
    tester,
  ) async {
    await pumpProfile(tester, width: 600);
    expect(tester.takeException(), isNull);
    expect(
      (rowTop(tester, 'Görünüm') - rowTop(tester, 'Sistem')).abs(),
      lessThan(20),
    );
  });

  for (final (width, scale) in [(400.0, 1.0), (320.0, 1.0), (360.0, 1.6)]) {
    testWidgets(
      '${width.toInt()} genişlik, yazı x$scale: satır taşmaz, seçici alta iner',
      (tester) async {
        await pumpProfile(tester, width: width, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('Koyu'), findsOneWidget);
        expect(
          rowTop(tester, 'Sistem'),
          greaterThan(rowTop(tester, 'Görünüm')),
        );
      },
    );
  }
}
