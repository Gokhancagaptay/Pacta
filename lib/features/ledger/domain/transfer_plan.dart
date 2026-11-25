import '../../../core/dates/local_date.dart';
import '../../../core/money/asset.dart';
import '../../../core/money/money.dart';
import 'models.dart';

/// Özel defterden ortak deftere tek tek aktarılan vade sayısı (birim başına).
const maxTransferDue = 10;

/// Özel defter ortak deftere taşınınca karşı tarafa gidecek bir kayıt.
class TransferLine {
  const TransferLine({
    required this.amount,
    required this.description,
    this.dueOn,
  });

  /// Defter sahibinin gözünden: pozitif = karşı taraf size borçlu.
  final Money amount;
  final LocalDate? dueOn;

  /// Karşı tarafın göreceği açıklama.
  final String description;

  /// Karşı tarafın onayını bekler mi (sahibin aleyhine olanlar beklemez).
  bool get needsApproval => amount.minor > 0;
}

/// Taşımada gidecekler (önizleme). Sunucudaki transferLines ile aynı kural:
/// her birimde açık vadeli parçalar (en fazla [maxTransferDue]) ayrı kayıt,
/// bakiyenin kalanı vadesiz tek kayıt. Açıklamalar istenmezse genel metin
/// yazılır; özel notlar karşı tarafa gitmez. Özel defterin sahibi a
/// tarafıdır.
List<TransferLine> transferPlan(
  Ledger ledger, {
  required bool withDescriptions,
}) {
  final lines = <TransferLine>[];
  final codes = ledger.balances.keys.toList()..sort();
  for (final code in codes) {
    final balance = ledger.balances[code] ?? 0;
    if (balance == 0) continue;
    final asset = Asset.fromCode(code);
    final sign = balance > 0 ? 1 : -1;
    var rest = balance.abs();
    final items = ledger.dueItems
        .where((i) => i.open.asset == asset)
        .take(maxTransferDue);
    for (final item in items) {
      lines.add(
        TransferLine(
          amount: Money(item.open.minor * sign, asset),
          dueOn: item.dueOn,
          description: withDescriptions && item.description.isNotEmpty
              ? item.description
              : 'Önceki kayıtlardan aktarıldı',
        ),
      );
      rest -= item.open.minor;
    }
    if (rest > 0) {
      lines.add(
        TransferLine(
          amount: Money(rest * sign, asset),
          description: 'Önceki kayıtlardan kalan bakiye',
        ),
      );
    }
  }
  return lines;
}
