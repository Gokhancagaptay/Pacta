import 'package:intl/intl.dart';

import '../../../core/dates/local_date.dart';
import '../../../core/money/asset.dart';
import '../../../core/money/money.dart';
import 'entry_text.dart';
import 'models.dart';
import 'statement_period.dart';

export 'statement_period.dart';

/// Hesap ekstresinde onaylı bir satır.
class StatementLine {
  const StatementLine({
    required this.entry,
    required this.amount,
    required this.balance,
  });

  final LedgerEntry entry;

  /// Kullanıcının gözünden etki (pozitif = alacağınız arttı).
  final Money amount;

  /// Bu satırdan sonra aynı birimdeki onaylı bakiye.
  final Money balance;
}

/// Bir kişiyle hesabın dökümü (PDF ekstre ve CSV için). Bakiyeye yalnızca
/// onaylı kayıtlar girer; bekleyenler ayrı listelenir, reddedilen ve geri
/// çekilenler yalnızca CSV'de durur.
///
/// [period] verilirse yalnızca işlem tarihi dönem içinde olan kayıtlar
/// listelenir (onaysızlar da aynı kuralla); yürüyen bakiye her birimde
/// devreden bakiyeden başlar ve [summary] birim başına devreden, hareket ve
/// dönem sonu bakiyesini verir.
class Statement {
  const Statement._({
    required this.ledger,
    required this.me,
    required this.confirmed,
    required this.open,
    required this.closedCount,
    required this.all,
    this.period,
    this.summary = const [],
  });

  factory Statement.of(
    Ledger ledger,
    List<LedgerEntry> entries,
    String uid, {
    StatementPeriod? period,
  }) {
    final me = ledger.sideOf(uid) ?? Side.a;
    final sorted = [...entries]..sort(_byDate);
    final summary = period == null
        ? const <PeriodBalance>[]
        : periodBalances(sorted, me, period);
    final ordered = period == null
        ? sorted
        : [
            for (final e in sorted)
              if (period.contains(e.occurredOn)) e,
          ];
    // Dönemli ekstrede yürüyen bakiye devreden bakiyeden başlar.
    final running = <Asset, int>{
      for (final b in summary) b.asset: b.opening.minor,
    };
    final confirmed = <StatementLine>[];
    for (final e in ordered.where(countsInBalance)) {
      final delta = e.deltaFor(me);
      final total = (running[e.asset] ?? 0) + delta;
      running[e.asset] = total;
      confirmed.add(
        StatementLine(
          entry: e,
          amount: Money(delta, e.asset),
          balance: Money(total, e.asset),
        ),
      );
    }
    return Statement._(
      ledger: ledger,
      me: me,
      confirmed: confirmed,
      open: [
        for (final e in ordered)
          if (e.isOpen) e,
      ],
      closedCount: ordered
          .where(
            (e) =>
                e.state == EntryState.rejected ||
                e.state == EntryState.cancelled,
          )
          .length,
      all: ordered,
      period: period,
      summary: summary,
    );
  }

  final Ledger ledger;
  final Side me;

  /// Ekstre dönemi; null ise tüm kayıtlar.
  final StatementPeriod? period;

  /// Dönemli ekstrede birim başına devreden, hareket ve dönem sonu bakiye.
  /// Tüm kayıtların ekstresinde boştur.
  final List<PeriodBalance> summary;

  /// Onaylı kayıtlar, işlem tarihine göre (yürüyen bakiyeyle).
  final List<StatementLine> confirmed;

  /// Onay ya da düzeltme bekleyenler (bakiyeye dahil değil).
  final List<LedgerEntry> open;

  /// Reddedilen ve geri çekilen kayıt sayısı.
  final int closedCount;

  /// Tüm kayıtlar, işlem tarihine göre.
  final List<LedgerEntry> all;

  LedgerSide get mine => me == Side.a ? ledger.a : ledger.b;
  LedgerSide get other => me == Side.a ? ledger.b : ledger.a;

  /// Onaylı bakiyeler (pozitif = karşı taraf size borçlu).
  List<Money> get balances {
    final sign = me == Side.a ? 1 : -1;
    return [
      for (final asset in Asset.values)
        if ((ledger.balances[asset.code] ?? 0) != 0)
          Money(ledger.balances[asset.code]! * sign, asset),
    ];
  }

  /// Dosya adı: "pacta-ayse-yilmaz-2026-09-27"; dönemli ekstrede tarih
  /// yerine dönem: "pacta-ayse-yilmaz-2026-11-01_2026-11-24".
  String fileName(LocalDate today) =>
      'pacta-${_slug(other.displayName)}-${period?.fileTag ?? today.toIso()}';

  /// Excel'in Türkçe ayarıyla açılan CSV: noktalı virgül ayraç, virgüllü
  /// ondalık, UTF-8 BOM (Türkçe harfler bozulmasın).
  ///
  /// Dönemli ekstrede ilk satır dönemdir; kayıtlardan önce her birimin
  /// "Devreden bakiye" satırı, sonra "Dönem sonu bakiye" satırı gelir.
  /// Devreden tutar "Bakiyeye etki" sütununa yazılır, dönem sonu yazılmaz:
  /// böylece sütun birim başına toplanınca yine dönem sonu bakiyeyi verir.
  String toCsv() {
    final date = DateFormat('dd.MM.yyyy');
    final p = period;
    final rows = <List<String>>[
      if (p != null) ['Dönem', p.label],
      [
        'İşlem tarihi',
        'Kayıt',
        'Açıklama',
        'Birim',
        'Tutar (sizin açınızdan)',
        // Excel'de toplanınca bakiyeyi verir: onaysızlar 0.
        'Bakiyeye etki',
        'Durum',
        'Vade',
        'Kaydı giren',
      ],
      if (p != null)
        for (final b in summary)
          [
            date.format(p.start.toDateTime()),
            'Devreden bakiye',
            '',
            b.asset.code,
            plainAmount(b.opening),
            plainAmount(b.opening),
            '',
            '',
            '',
          ],
      for (final e in all)
        [
          date.format(e.occurredOn.toDateTime()),
          EntryText.title(e, me),
          e.description,
          e.asset.code,
          plainAmount(Money(e.deltaFor(me), e.asset)),
          plainAmount(
            Money(
              e.state == EntryState.confirmed ? e.deltaFor(me) : 0,
              e.asset,
            ),
          ),
          EntryText.status(e, me, isPrivate: ledger.isPrivate).label,
          e.dueOn == null ? '' : date.format(e.dueOn!.toDateTime()),
          e.proposedBy == me ? mine.displayName : other.displayName,
        ],
      if (p != null)
        for (final b in summary)
          [
            date.format(p.end.toDateTime()),
            'Dönem sonu bakiye',
            '',
            b.asset.code,
            plainAmount(b.closing),
            '',
            '',
            '',
            '',
          ],
    ];
    return '\uFEFF${rows.map((r) => r.map(csvCell).join(';')).join('\r\n')}'
        '\r\n';
  }

  static int _byDate(LedgerEntry x, LedgerEntry y) {
    final c = x.occurredOn.compareTo(y.occurredOn);
    if (c != 0) return c;
    final tx = x.createdAt;
    final ty = y.createdAt;
    if (tx != null && ty != null && tx != ty) return tx.compareTo(ty);
    return x.id.compareTo(y.id);
  }
}

/// Gruplamasız, virgüllü ondalık: "-1250,50" (tablo programları için).
String plainAmount(Money m) {
  final scale = m.asset.scale;
  final negative = m.minor < 0;
  final digits = m.minor.abs().toString().padLeft(scale + 1, '0');
  final whole = digits.substring(0, digits.length - scale);
  final fraction = digits.substring(digits.length - scale);
  final number = scale == 0 ? whole : '$whole,$fraction';
  return negative ? '-$number' : number;
}

/// CSV hücresi: ayraç/tırnak kaçışı ve formül enjeksiyonuna karşı koruma.
String csvCell(String value) {
  // Formül olarak çalıştırılmasın (=, +, -, @, sekme, satır başı ile
  // başlayan metin). Yalnızca tamamı sayı olan hücre ("-1234,50", tutar
  // sütunu) olduğu gibi kalır; "-1+..." gibi metinler kaçırılır.
  var v = value;
  if (RegExp('^[=+\\-@\t\r]').hasMatch(v) &&
      !RegExp(r'^-?\d+(,\d+)?$').hasMatch(v)) {
    v = "'$v";
  }
  if (v.contains(RegExp('[;"\r\n]'))) {
    v = '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

String _slug(String name) {
  const map = {
    'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', //
    'Ç': 'c', 'Ğ': 'g', 'I': 'i', 'İ': 'i', 'Ö': 'o', 'Ş': 's', 'Ü': 'u',
  };
  final ascii = name.split('').map((ch) => map[ch] ?? ch.toLowerCase()).join();
  final slug = ascii
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'kisi' : slug;
}
