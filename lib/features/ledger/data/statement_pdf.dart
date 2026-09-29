import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/money/money.dart';
import '../domain/entry_text.dart';
import '../domain/models.dart';
import '../domain/people_summary.dart';
import '../domain/statement.dart';
import '../domain/summary.dart';

const _green = PdfColor.fromInt(0xFF16A34A);
const _red = PdfColor.fromInt(0xFFDC2626);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _line = PdfColor.fromInt(0xFFE5E7EB);
const _soft = PdfColor.fromInt(0xFFF1F2F6);

/// Kişiyle hesabın PDF ekstresi. Yazı tipi uygulamaya gömülü Poppins'tir
/// (Türkçe harfler ve ₺); internet gerekmez.
Future<Uint8List> buildStatementPdf(
  Statement st, {
  required DateTime now,
}) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/google_fonts/Poppins-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/google_fonts/Poppins-SemiBold.ttf'),
  );
  final doc = pw.Document(
    title: 'Pacta hesap ekstresi · ${st.other.displayName}',
    author: 'Pacta',
    creator: 'Pacta',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  final created = DateFormat('d MMMM y HH:mm', 'tr_TR').format(now);
  final date = DateFormat('dd.MM.yyyy');
  final small = const pw.TextStyle(fontSize: 8, color: _muted);
  final ledger = st.ledger;

  pw.Widget amount(Money m, {bool colored = true}) => pw.Text(
    m.format(signed: true),
    textAlign: pw.TextAlign.right,
    style: pw.TextStyle(
      fontSize: 9,
      color: !colored || m.minor == 0 ? null : (m.minor > 0 ? _green : _red),
    ),
  );

  pw.Widget cell(String text, {pw.TextStyle? style}) =>
      pw.Text(text, style: style ?? const pw.TextStyle(fontSize: 9));

  pw.Widget table(List<String> headers, List<List<pw.Widget>> rows) => pw.Table(
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _line, width: 0.5),
      bottom: pw.BorderSide(color: _line, width: 0.5),
    ),
    columnWidths: {
      0: const pw.FixedColumnWidth(58),
      1: const pw.FixedColumnWidth(78),
      2: const pw.FlexColumnWidth(),
      3: const pw.FixedColumnWidth(78),
      if (headers.length > 4) 4: const pw.FixedColumnWidth(78),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _soft),
        children: [
          for (var i = 0; i < headers.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                headers[i],
                textAlign: i >= 3 ? pw.TextAlign.right : null,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      for (final row in rows)
        pw.TableRow(
          children: [
            for (final c in row)
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: c),
          ],
        ),
    ],
  );

  pw.Widget section(String title, {String? note}) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        if (note != null) ...[
          pw.SizedBox(width: 6),
          pw.Text(note, style: small),
        ],
      ],
    ),
  );

  String party(LedgerSide s) =>
      s.email == null ? s.displayName : '${s.displayName} · ${s.email}';

  final balances = st.balances;
  final me = st.me;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                'Pacta · ${st.other.displayName} ile hesap ekstresi',
                style: small,
              ),
            ),
      footer: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Divider(color: _line, thickness: 0.5),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Bu belge Pacta\'daki kayıtların dökümüdür; senet ya da '
                  'resmî belge değildir. Kayıt zinciri: '
                  '#${ledger.chainSeq}'
                  '${ledger.chainHash.length >= 16 ? ' · ${ledger.chainHash.substring(0, 16)}' : ''}',
                  style: small,
                ),
              ),
              pw.Text(
                'Sayfa ${context.pageNumber}/${context.pagesCount}',
                style: small,
              ),
            ],
          ),
        ],
      ),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Hesap ekstresi',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text('Oluşturma: $created', style: small),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: pw.BoxDecoration(
                color: _green,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'Pacta',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _soft,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Siz: ${party(st.mine)}', style: small),
              pw.Text(
                ledger.isPrivate
                    ? 'Kişi: ${st.other.displayName}'
                    : 'Karşı taraf: ${party(st.other)}',
                style: small,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                ledger.isPrivate
                    ? 'Özel defter: kayıtlar yalnızca sizin beyanınızdır, '
                          'karşı taraf onaylamamıştır.'
                    : 'Ortak defter: bakiyeye yalnızca iki tarafın onayladığı '
                          'kayıtlar girer.',
                style: small,
              ),
            ],
          ),
        ),
        section('Bakiye'),
        if (balances.isEmpty)
          pw.Text('Hesap denk.', style: const pw.TextStyle(fontSize: 10))
        else
          for (final m in balances)
            pw.Text(
              m.minor > 0
                  ? '${st.other.displayName} size ${m.format()} borçlu.'
                  : '${st.other.displayName} kişisine ${(-m).format()} '
                        'borcunuz var.',
              style: pw.TextStyle(
                fontSize: 11,
                color: m.minor > 0 ? _green : _red,
              ),
            ),
        // Özel defterde karşı tarafın onayı yoktur; "onaylı" denmez.
        section(
          ledger.isPrivate ? 'Kayıtlar' : 'Onaylı kayıtlar',
          note: 'Tutarlar sizin açınızdan: + alacağınız artar',
        ),
        if (st.confirmed.isEmpty)
          pw.Text(
            ledger.isPrivate ? 'Kayıt yok.' : 'Onaylı kayıt yok.',
            style: small,
          )
        else
          table(
            ['Tarih', 'Kayıt', 'Açıklama', 'Tutar', 'Bakiye'],
            [
              for (final l in st.confirmed)
                [
                  cell(date.format(l.entry.occurredOn.toDateTime())),
                  cell(EntryText.title(l.entry, me)),
                  cell(
                    [
                      l.entry.description,
                      if (l.entry.dueOn != null)
                        'Vade ${date.format(l.entry.dueOn!.toDateTime())}',
                      // Özel defterde karşı tarafın web'deki yanıtı kanıttır.
                      if (ledger.isPrivate && l.entry.webConfirmation != null)
                        EntryText.webStatus(l.entry.webConfirmation!).label +
                            (l.entry.webConfirmation!.emailMasked == null
                                ? ''
                                : ' (${l.entry.webConfirmation!.emailMasked})'),
                    ].where((t) => t.isNotEmpty).join(' · '),
                  ),
                  amount(l.amount),
                  amount(l.balance, colored: false),
                ],
            ],
          ),
        if (st.open.isNotEmpty) ...[
          section('Onay bekleyenler', note: 'Bakiyeye dahil değildir'),
          table(
            ['Tarih', 'Kayıt', 'Açıklama', 'Tutar', 'Durum'],
            [
              for (final e in st.open)
                [
                  cell(date.format(e.occurredOn.toDateTime())),
                  cell(EntryText.title(e, me)),
                  cell(e.description),
                  amount(Money(e.deltaFor(me), e.asset)),
                  cell(
                    EntryText.status(e, me).label,
                    style: const pw.TextStyle(fontSize: 8, color: _muted),
                  ),
                ],
            ],
          ),
        ],
        if (ledger.dueItems.isNotEmpty && !ledger.isClosed) ...[
          section('Açık vadeler'),
          table(
            ['Vade', 'Kim ödeyecek', 'Açıklama', 'Tutar'],
            [
              for (final d in ledger.dueItems)
                [
                  cell(date.format(d.dueOn.toDateTime())),
                  cell(d.debtorSide == me ? 'Siz' : st.other.displayName),
                  cell(d.description),
                  amount(d.signedFor(me)),
                ],
            ],
          ),
        ],
        if (st.closedCount > 0)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              '${st.closedCount} reddedilen ya da geri çekilen kayıt bu '
              'dökümde yok; CSV dosyasında yer alır.',
              style: small,
            ),
          ),
      ],
    ),
  );
  return doc.save();
}

/// Kişiler özeti (görünen satırlar): kişi, TL bakiye, diğer birimler,
/// bekleyen, sonraki vade; en altta toplamlar.
Future<Uint8List> buildPeopleSummaryPdf(
  PeopleSummary summary, {
  required DateTime now,
  required String ownerName,
}) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/google_fonts/Poppins-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/google_fonts/Poppins-SemiBold.ttf'),
  );
  final doc = pw.Document(
    title: 'Pacta kişiler özeti',
    author: 'Pacta',
    creator: 'Pacta',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  final created = DateFormat('d MMMM y HH:mm', 'tr_TR').format(now);
  final date = DateFormat('dd.MM.yyyy');
  const small = pw.TextStyle(fontSize: 8, color: _muted);
  const body = pw.TextStyle(fontSize: 9);

  pw.Widget amount(Money m, {double size = 9}) => pw.Text(
    m.format(signed: true),
    textAlign: pw.TextAlign.right,
    style: pw.TextStyle(
      fontSize: size,
      color: m.minor == 0 ? null : (m.minor > 0 ? _green : _red),
    ),
  );

  pw.Widget pad(pw.Widget child) =>
      pw.Padding(padding: const pw.EdgeInsets.all(5), child: child);

  pw.Widget head(String text, {bool right = false}) => pad(
    pw.Text(
      text,
      textAlign: right ? pw.TextAlign.right : null,
      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    ),
  );

  final t = summary.totals;
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
      footer: (context) => pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'Tutarlar sizin açınızdan: + alacağınız, - borcunuz. Bakiyeye '
              'yalnızca onaylı kayıtlar girer.',
              style: small,
            ),
          ),
          pw.Text(
            'Sayfa ${context.pageNumber}/${context.pagesCount}',
            style: small,
          ),
        ],
      ),
      build: (context) => [
        pw.Text(
          'Kişiler özeti',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          '$ownerName · $created · '
          '${summary.filter == PeopleFilter.all ? 'Tüm kişiler' : summary.filter.label}'
          '${summary.query.isEmpty ? '' : ' · "${summary.query}" araması'} '
          '(${summary.rows.length})',
          style: small,
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            for (final (label, value) in [
              ('Alacağınız', t.receivable),
              ('Borcunuz', -t.payable),
              ('Net', t.net),
            ])
              pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.only(right: 8),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: _soft,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(label, style: small),
                      pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: amount(value, size: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Table(
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: _line, width: 0.5),
            bottom: pw.BorderSide(color: _line, width: 0.5),
          ),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FixedColumnWidth(80),
            2: pw.FlexColumnWidth(2),
            3: pw.FixedColumnWidth(48),
            4: pw.FixedColumnWidth(62),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _soft),
              children: [
                head('Kişi'),
                head('TL bakiye', right: true),
                head('Diğer birimler', right: true),
                head('Bekleyen', right: true),
                head('Sonraki vade', right: true),
              ],
            ),
            for (final r in summary.rows)
              pw.TableRow(
                children: [
                  pad(
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(r.name, style: body),
                        if (r.email != null) pw.Text(r.email!, style: small),
                      ],
                    ),
                  ),
                  pad(amount(r.balance)),
                  pad(
                    pw.Text(
                      r.others.map((m) => m.format(signed: true)).join('\n'),
                      textAlign: pw.TextAlign.right,
                      style: body,
                    ),
                  ),
                  pad(
                    pw.Text(
                      r.pendingCount > 0 ? '${r.pendingCount}' : '-',
                      textAlign: pw.TextAlign.right,
                      style: body,
                    ),
                  ),
                  pad(
                    pw.Text(
                      r.nextDue == null
                          ? '-'
                          : date.format(r.nextDue!.dueOn.toDateTime()),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: r.hasOverdue ? _red : null,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}
