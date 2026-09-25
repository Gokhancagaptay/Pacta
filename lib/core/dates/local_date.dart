import 'package:intl/intl.dart';

/// Sunucuyla `YYYY-MM-DD` biçiminde takas edilen, saat dilimsiz gün.
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  factory LocalDate.fromDateTime(DateTime value) =>
      LocalDate(value.year, value.month, value.day);

  factory LocalDate.today() => LocalDate.fromDateTime(DateTime.now());

  factory LocalDate.parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) throw FormatException('Geçersiz tarih: $value');
    return LocalDate(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
  }

  static LocalDate? tryParse(String? value) =>
      value == null ? null : LocalDate.parse(value);

  final int year;
  final int month;
  final int day;

  DateTime toDateTime() => DateTime(year, month, day);

  LocalDate addDays(int days) =>
      LocalDate.fromDateTime(DateTime(year, month, day + days));

  LocalDate addMonths(int months) {
    final target = DateTime(year, month + months, 1);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    return LocalDate(target.year, target.month, day > lastDay ? lastDay : day);
  }

  /// Sunucu biçimi: 2026-09-25.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// "25 Eylül 2026".
  String format() => DateFormat('d MMMM y', 'tr_TR').format(toDateTime());

  /// "25 Eylül" (bu yılsa yıl yazılmaz).
  String formatShort() => year == DateTime.now().year
      ? DateFormat('d MMMM', 'tr_TR').format(toDateTime())
      : format();

  /// "Eylül 2026" (liste grupları için).
  String formatMonth() => DateFormat('MMMM y', 'tr_TR').format(toDateTime());

  @override
  int compareTo(LocalDate other) => toIso().compareTo(other.toIso());

  bool operator <(LocalDate other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
