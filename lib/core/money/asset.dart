/// Borç kayıtlarında kullanılabilen birimler.
///
/// Sunucudaki karşılığı `functions/src/ledger/assets.ts`; ikisi de
/// `contracts/assets.json` ile testlerde karşılaştırılır.
class Asset {
  const Asset._(this.code, this.scale, this.symbol, this.label);

  /// Sunucuya ve veritabanına yazılan kod (ör. `TRY`).
  final String code;

  /// Küçük birimin basamak sayısı: TRY için 2 (kuruş), gram altın için 3.
  final int scale;

  final String symbol;
  final String label;

  static const tryLira = Asset._('TRY', 2, '₺', 'Türk lirası');
  static const usd = Asset._('USD', 2, r'$', 'ABD doları');
  static const eur = Asset._('EUR', 2, '€', 'Euro');
  static const gramAltin = Asset._('GAU', 3, 'gr', 'Gram altın');
  static const ceyrek = Asset._('CEYREK', 0, 'çeyrek', 'Çeyrek altın');

  static const values = [tryLira, usd, eur, gramAltin, ceyrek];

  static Asset fromCode(String code) {
    for (final asset in values) {
      if (asset.code == code) return asset;
    }
    throw FormatException('Bilinmeyen birim: $code');
  }

  @override
  String toString() => code;
}
