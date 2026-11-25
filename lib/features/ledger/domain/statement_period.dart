import 'package:intl/intl.dart';

import '../../../core/dates/local_date.dart';
import '../../../core/money/asset.dart';
import '../../../core/money/money.dart';
import 'models.dart';

/// Ekstre dönemi: işlem tarihine (`occurredOn`) göre, iki uç da dahil.
class StatementPeriod {
  const StatementPeriod(this.start, this.end);

  final LocalDate start;
  final LocalDate end;

  bool contains(LocalDate day) => !(day < start) && !(end < day);

  /// "01.11.2026 - 24.11.2026" (CSV ve PDF başlığı).
  String get label {
    final f = DateFormat('dd.MM.yyyy');
    return '${f.format(start.toDateTime())} - ${f.format(end.toDateTime())}';
  }

  /// Dosya adı parçası: "2026-11-01_2026-11-24" (yalnız rakam, tire, alt
  /// çizgi; her dosya sisteminde geçerli).
  String get fileTag => '${start.toIso()}_${end.toIso()}';

  @override
  bool operator ==(Object other) =>
      other is StatementPeriod && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => fileTag;
}

/// Dışa aktarmadan önce sunulan dönem seçenekleri.
enum PeriodChoice {
  all('Tüm kayıtlar'),
  thisMonth('Bu ay'),
  lastMonth('Geçen ay'),
  last3Months('Son 3 ay'),
  custom('Tarih aralığı seç');

  const PeriodChoice(this.label);
  final String label;

  /// Hazır seçeneğin dönemi. "Tüm kayıtlar" ve elle seçilen aralık için
  /// null (ilki dönemsizdir, ikincisini tarih seçici verir).
  StatementPeriod? periodFor(LocalDate today) => switch (this) {
    all || custom => null,
    // Ayın başından bugüne.
    thisMonth => StatementPeriod(LocalDate(today.year, today.month, 1), today),
    // Önceki takvim ayının tamamı.
    lastMonth => StatementPeriod(
      LocalDate(today.year, today.month, 1).addMonths(-1),
      LocalDate(today.year, today.month, 1).addDays(-1),
    ),
    // Bugün dahil son üç ay: 25 Ağustos - 24 Kasım.
    last3Months => StatementPeriod(today.addMonths(-3).addDays(1), today),
  };
}

/// Bir birimin dönem özeti, kullanıcının gözünden (pozitif = alacağınız).
class PeriodBalance {
  const PeriodBalance({
    required this.opening,
    required this.movement,
    required this.closing,
  });

  /// Dönem başlamadan önceki onaylı kayıtların toplamı ("Devreden bakiye").
  final Money opening;

  /// Dönem içindeki onaylı kayıtların toplamı.
  final Money movement;

  /// Dönem sonundaki bakiye: [opening] + [movement].
  final Money closing;

  Asset get asset => opening.asset;
}

/// Bakiyeye giren kayıt mı. Tam ekstreyle aynı kural: yalnızca onaylı
/// kayıtlar. Ters kayıtla düzeltilen kayıt da onaylı kalır; düzeltme kaydı
/// ters etkiyle ayrıca girer (sunucudaki bakiye de böyle oluşur).
bool countsInBalance(LedgerEntry e) => e.state == EntryState.confirmed;

/// Her birim için devreden bakiye, dönem hareketi ve dönem sonu bakiye.
///
/// Devreden: dönem başından önceki onaylı kayıtlar. Hareket: dönem içindeki
/// onaylı kayıtlar (iki uç dahil). Dönem sonundan sonraki kayıtlar
/// hiçbirine girmez. Birimler karışmaz; dönem öncesinde ve içinde hiç onaylı
/// kaydı olmayan birim listede yer almaz. Sıra [Asset.values] sırasıdır.
List<PeriodBalance> periodBalances(
  List<LedgerEntry> entries,
  Side me,
  StatementPeriod period,
) {
  final opening = <Asset, int>{};
  final movement = <Asset, int>{};
  for (final e in entries) {
    if (!countsInBalance(e) || period.end < e.occurredOn) continue;
    final target = e.occurredOn < period.start ? opening : movement;
    target[e.asset] = (target[e.asset] ?? 0) + e.deltaFor(me);
  }
  return [
    for (final asset in Asset.values)
      if (opening.containsKey(asset) || movement.containsKey(asset))
        PeriodBalance(
          opening: Money(opening[asset] ?? 0, asset),
          movement: Money(movement[asset] ?? 0, asset),
          closing: Money((opening[asset] ?? 0) + (movement[asset] ?? 0), asset),
        ),
  ];
}
