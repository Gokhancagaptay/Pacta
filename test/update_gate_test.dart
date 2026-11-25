import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacta/app/theme.dart';
import 'package:pacta/app/update_gate.dart';
import 'package:pacta/constants/app_constants.dart';

void main() {
  setUpAll(() => PactaTheme.useGoogleFonts = false);

  Widget app(Stream<int?> minBuild) => ProviderScope(
    overrides: [minBuildProvider.overrideWith((ref) => minBuild)],
    child: MaterialApp(
      theme: PactaTheme.light,
      home: const Scaffold(body: Text('ana ekran')),
      builder: (context, child) => UpdateGate(child: child!),
    ),
  );

  testWidgets('ayar yoksa ya da sürüm yeterliyse uygulama açılır', (
    tester,
  ) async {
    for (final value in [null, AppConstants.buildNumber, 1]) {
      await tester.pumpWidget(app(Stream.value(value)));
      await tester.pump();
      expect(find.text('ana ekran'), findsOneWidget);
      expect(find.text('Güncelleme gerekli'), findsNothing);
    }
  });

  testWidgets('ayar okunamazsa uygulama engellenmez', (tester) async {
    await tester.pumpWidget(app(Stream.error(StateError('ağ yok'))));
    await tester.pump();
    expect(find.text('ana ekran'), findsOneWidget);
  });

  testWidgets('daha yeni sürüm zorunluysa güncelleme ekranı kalır', (
    tester,
  ) async {
    await tester.pumpWidget(app(Stream.value(AppConstants.buildNumber + 1)));
    await tester.pump();
    expect(find.text('Güncelleme gerekli'), findsOneWidget);
    expect(find.text('Güncelle'), findsOneWidget);
    expect(find.text('ana ekran'), findsNothing);
  });

  test('derleme numarası pubspec ile aynı', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final build = RegExp(
      r'^version:\s*(\S+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(build, isNotNull);
    expect(int.parse(build![2]!), AppConstants.buildNumber);
    expect(build[1], AppConstants.appVersion);
  });
}
