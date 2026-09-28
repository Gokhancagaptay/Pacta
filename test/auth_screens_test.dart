import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/screens/auth/giris_ekrani.dart';
import 'package:pacta/screens/auth/kayit_ekrani.dart';

Widget _app(Widget home) => MaterialApp(theme: PactaTheme.light, home: home);

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => PactaTheme.useGoogleFonts = false);

  testWidgets('giriş: boş form gönderilmez, alanlar hatayı gösterir', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(_app(const GirisEkrani()));
    expect(find.text('Giriş yapın'), findsOneWidget);
    expect(find.textContaining('👋'), findsNothing);

    await tester.tap(find.text('Giriş yap'));
    await tester.pump();
    expect(find.text('E-posta adresinizi girin.'), findsOneWidget);
    expect(find.text('Şifrenizi girin.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'ali@');
    await tester.tap(find.text('Giriş yap'));
    await tester.pump();
    expect(find.text('Geçerli bir e-posta adresi girin.'), findsOneWidget);
  });

  testWidgets('kayıt: kısa şifre ve onaysız koşullar durdurur', (tester) async {
    phone(tester);
    await tester.pumpWidget(_app(const KayitEkrani()));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ali Veli');
    await tester.enterText(fields.at(1), 'ali@example.com');
    await tester.enterText(fields.at(2), '1234567');

    final submit = find.text('Hesap oluştur').last;
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Şifre en az 8 karakter olmalı.'), findsOneWidget);

    await tester.enterText(fields.at(2), '12345678');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(
      find.textContaining('Kullanım Koşulları\'nı kabul edin'),
      findsOneWidget,
    );
  });
}
