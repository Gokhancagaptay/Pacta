import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pacta/core/dates/local_date.dart';
import 'package:pacta/core/text/turkish.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('Türkçe metin', () {
    test('büyük/küçük harf', () {
      expect(trUpper('istanbul ılık'), 'İSTANBUL ILIK');
      expect(trLower('İZMİR IŞIK'), 'izmir ışık');
    });

    test('baş harfler', () {
      expect(initials('ayşe yılmaz'), 'AY');
      expect(initials('  İlker  '), 'İ');
      expect(initials('ismail ışık kaya'), 'İI');
      expect(initials(''), '?');
    });
  });

  group('LocalDate', () {
    test('ISO biçimi gidiş-dönüş', () {
      final d = LocalDate.parse('2026-02-05');
      expect(d.toIso(), '2026-02-05');
      expect(() => LocalDate.parse('2026-2-5'), throwsFormatException);
    });

    test('ay ekleme ay sonunu taşırmaz', () {
      expect(LocalDate.parse('2026-01-31').addMonths(1).toIso(), '2026-02-28');
      expect(LocalDate.parse('2026-12-15').addMonths(1).toIso(), '2027-01-15');
      expect(LocalDate.parse('2026-09-25').addDays(7).toIso(), '2026-10-02');
    });

    test('Türkçe gösterim ve sıralama', () {
      expect(LocalDate.parse('2026-09-22').format(), '22 Eylül 2026');
      expect(LocalDate.parse('2026-09-22').formatMonth(), 'Eylül 2026');
      expect(LocalDate.parse('2026-09-22') < LocalDate.parse('2026-10-01'), isTrue);
    });
  });
}
