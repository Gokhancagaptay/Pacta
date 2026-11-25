import 'package:intl/intl.dart';

import '../../../core/dates/local_date.dart';
import 'statement.dart';
import 'summary.dart';

/// Kişiler tablosunun dışa aktarımı (görünen satırlar, süzgeç uygulanmış).
class PeopleSummary {
  const PeopleSummary({
    required this.rows,
    required this.totals,
    required this.filter,
    this.query = '',
  });

  final List<PersonRow> rows;
  final SummaryTotals totals;
  final PeopleFilter filter;

  /// Kişi araması (başlıkta yazılır; satırlar zaten süzülmüştür).
  final String query;

  /// "pacta-kisiler-2026-09-28".
  String fileName(LocalDate today) => 'pacta-kisiler-${today.toIso()}';

  /// Excel'in Türkçe ayarıyla açılır (noktalı virgül, virgüllü ondalık,
  /// UTF-8 BOM). Tutarlar sizin açınızdan: + alacağınız, - borcunuz.
  String toCsv() {
    final date = DateFormat('dd.MM.yyyy');
    final lines = <List<String>>[
      [
        'Kişi',
        'E-posta',
        'TL bakiye',
        'Diğer birimler',
        'Onay bekleyen',
        'Sonraki vade',
        'Vadesi geçmiş',
      ],
      for (final r in rows)
        [
          r.name,
          r.email ?? '',
          plainAmount(r.balance),
          r.others.map((m) => '${plainAmount(m)} ${m.asset.code}').join(' / '),
          '${r.pendingCount}',
          r.nextDue == null ? '' : date.format(r.nextDue!.dueOn.toDateTime()),
          r.hasOverdue ? 'Evet' : '',
        ],
      // PDF'teki toplamlar CSV'de de (TL).
      ['Toplam alacak', '', plainAmount(totals.receivable), '', '', '', ''],
      ['Toplam borç', '', plainAmount(-totals.payable), '', '', '', ''],
    ];
    return '\uFEFF${lines.map((l) => l.map(csvCell).join(';')).join('\r\n')}'
        '\r\n';
  }
}
