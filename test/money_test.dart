import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pacta/core/money/asset.dart';
import 'package:pacta/core/money/money.dart';

void main() {
  group('Money.parse', () {
    int parse(String input, [Asset asset = Asset.tryLira]) =>
        Money.parse(input, asset).minor;

    test('virgül ondalık, nokta binlik', () {
      expect(parse('12,5'), 1250);
      expect(parse('1.234,56'), 123456);
      expect(parse('1.500'), 150000);
      expect(parse('1.234.567'), 123456700);
      expect(parse('150'), 15000);
      expect(parse(',5'), 50);
    });

    test('virgülsüz tek nokta ve üç basamak değilse ondalık sayılır', () {
      expect(parse('12.5'), 1250);
      expect(parse('0.75'), 75);
    });

    test('boşluk ve sembol yok sayılır', () {
      expect(parse(' 1.200,00 ₺ '), 120000);
    });

    test('birimin ondalık basamağına uyar', () {
      expect(parse('2,125', Asset.gramAltin), 2125);
      expect(parse('3', Asset.ceyrek), 3);
      expect(() => parse('1,5', Asset.ceyrek), throwsFormatException);
      expect(() => parse('1,555'), throwsFormatException);
    });

    test('geçersiz girişler reddedilir', () {
      for (final bad in ['', 'abc', '-5', '1,2,3', '1.2.3,4.5', '12.5.1']) {
        expect(() => parse(bad), throwsFormatException, reason: bad);
      }
      expect(() => parse('999.999.999.999,00'), throwsFormatException);
    });
  });

  group('Money.format', () {
    test('Türkçe biçim ve işaret', () {
      expect(const Money(123450, Asset.tryLira).format(), '1.234,50 ₺');
      expect(const Money(-75000, Asset.tryLira).format(), '−750,00 ₺');
      expect(const Money(270000, Asset.tryLira).format(signed: true), '+2.700,00 ₺');
      expect(const Money(0, Asset.tryLira).format(signed: true), '0,00 ₺');
      expect(const Money(5, Asset.tryLira).format(withSymbol: false), '0,05');
      expect(const Money(2125, Asset.gramAltin).format(), '2,125 gr');
      expect(const Money(2, Asset.ceyrek).format(), '2 çeyrek');
    });
  });

  group('Money.allocate', () {
    test('toplam korunur, kalan en büyük kalana gider', () {
      final parts = const Money(10000, Asset.tryLira).allocate([1, 1, 1]);
      expect(parts.map((m) => m.minor), [3334, 3333, 3333]);
      expect(parts.fold<int>(0, (s, m) => s + m.minor), 10000);
    });

    test('farklı oranlar', () {
      final parts = const Money(100, Asset.tryLira).allocate([1, 2]);
      expect(parts.map((m) => m.minor), [33, 67]);
    });
  });

  test('çok uzun tutar Türkçe hatayla reddedilir', () {
    expect(
      () => Money.parse('9' * 30, Asset.tryLira),
      throwsA(isA<FormatException>().having((e) => e.message, 'mesaj', 'Tutar çok büyük.')),
    );
    expect(Money.parse('00012,5', Asset.tryLira).minor, 1250);
  });

  test('farklı birimler toplanamaz', () {
    expect(
      () => const Money(1, Asset.tryLira) + const Money(1, Asset.usd),
      throwsArgumentError,
    );
  });

  test('birimler contracts/assets.json ile aynı', () {
    final contract = (jsonDecode(File('contracts/assets.json').readAsStringSync())
            as List)
        .cast<Map<String, dynamic>>();
    expect(
      contract.map((a) => [a['code'], a['scale'], a['symbol'], a['label']]),
      Asset.values.map((a) => [a.code, a.scale, a.symbol, a.label]),
    );
  });
}
