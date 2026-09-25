import 'asset.dart';

/// Tamsayı küçük birim (kuruş, miligram, adet) cinsinden tutar.
///
/// `double` kullanılmaz: 0,1 + 0,2 gibi hesaplarda kuruş kaybolmasın.
class Money {
  const Money(this.minor, this.asset);

  /// Sunucunun kabul ettiği en büyük tutar (JS tarafında 2^53 altında kalır).
  static const maxMinor = 10000000000000;

  final int minor;
  final Asset asset;

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;

  /// Türkçe girişi küçük birime çevirir.
  ///
  /// Virgül ondalık ayıracıdır, nokta binlik ayıracıdır: "1.234,56" → 123456.
  /// Virgül yoksa ve noktadan sonra üç basamaklı gruplar gelmiyorsa nokta
  /// ondalık sayılır ("12.5" → 1250); böylece yanlış klavye düzeni tutarı
  /// 10 katına çıkarmaz.
  factory Money.parse(String input, Asset asset) {
    var text = input.replaceAll(RegExp(r'\s'), '').replaceAll(asset.symbol, '');
    if (text.isEmpty) throw const FormatException('Tutar boş.');
    if (!RegExp(r'^[0-9.,]+$').hasMatch(text)) {
      throw FormatException('Geçersiz tutar: $input');
    }

    String whole;
    String fraction;
    if (text.contains(',')) {
      final parts = text.split(',');
      if (parts.length != 2) throw FormatException('Geçersiz tutar: $input');
      whole = parts[0].replaceAll('.', '');
      fraction = parts[1];
      if (fraction.contains('.')) throw FormatException('Geçersiz tutar: $input');
    } else if (text.contains('.')) {
      final groups = text.split('.');
      final isThousands = groups.skip(1).every((g) => g.length == 3);
      if (isThousands) {
        whole = groups.join();
        fraction = '';
      } else if (groups.length == 2) {
        whole = groups[0];
        fraction = groups[1];
      } else {
        throw FormatException('Geçersiz tutar: $input');
      }
    } else {
      whole = text;
      fraction = '';
    }

    if (whole.isEmpty) whole = '0';
    if (fraction.length > asset.scale) {
      throw FormatException(
        '${asset.label} için en fazla ${asset.scale} ondalık basamak girilebilir.',
      );
    }
    final minorText = whole + fraction.padRight(asset.scale, '0');
    final minor = int.parse(minorText);
    if (minor > maxMinor) throw const FormatException('Tutar çok büyük.');
    return Money(minor, asset);
  }

  Money operator +(Money other) => Money(minor + _same(other).minor, asset);
  Money operator -(Money other) => Money(minor - _same(other).minor, asset);
  Money operator -() => Money(-minor, asset);

  /// Tutarı oranlara böler; kalan küçük birimler en büyük kalan yöntemiyle
  /// dağıtılır, toplam hiçbir zaman değişmez (taksit ve bölüşüm için).
  List<Money> allocate(List<int> ratios) {
    if (ratios.isEmpty || ratios.any((r) => r < 0)) {
      throw ArgumentError('Oranlar boş veya negatif olamaz.');
    }
    final total = ratios.fold<int>(0, (a, b) => a + b);
    if (total == 0) throw ArgumentError('Oranların toplamı sıfır olamaz.');

    final shares = <int>[];
    final remainders = <int>[];
    var allocated = 0;
    for (final ratio in ratios) {
      final share = minor * ratio ~/ total;
      shares.add(share);
      remainders.add(minor * ratio % total);
      allocated += share;
    }
    var left = minor - allocated;
    final order = List<int>.generate(ratios.length, (i) => i)
      ..sort((a, b) => remainders[b].compareTo(remainders[a]));
    for (final i in order) {
      if (left == 0) break;
      shares[i] += 1;
      left -= 1;
    }
    return [for (final share in shares) Money(share, asset)];
  }

  /// "1.234,50 ₺" biçiminde yazar. [signed] açıksa pozitifte "+" eklenir.
  String format({bool signed = false, bool withSymbol = true}) {
    final absolute = minor.abs();
    final unit = _pow10(asset.scale);
    final whole = absolute ~/ unit;
    final fraction = absolute % unit;

    final digits = whole.toString();
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
      grouped.write(digits[i]);
    }
    final number = asset.scale == 0
        ? grouped.toString()
        : '$grouped,${fraction.toString().padLeft(asset.scale, '0')}';

    final sign = minor < 0 ? '−' : (signed && minor > 0 ? '+' : '');
    return withSymbol ? '$sign$number ${asset.symbol}' : '$sign$number';
  }

  Money _same(Money other) {
    if (other.asset.code != asset.code) {
      throw ArgumentError('Farklı birimler toplanamaz: $asset / ${other.asset}');
    }
    return other;
  }

  static int _pow10(int n) {
    var result = 1;
    for (var i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.asset.code == asset.code;

  @override
  int get hashCode => Object.hash(minor, asset.code);

  @override
  String toString() => format();
}
