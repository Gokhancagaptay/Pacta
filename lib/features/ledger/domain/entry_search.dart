import '../../../core/text/turkish.dart';
import 'entry_text.dart';
import 'models.dart';

/// Sorgunun kelimeleri (Türkçe küçük harfle). Kayıt, her kelime görünen
/// metinlerinden birinde geçiyorsa eşleşir: "ödeme 250".
List<String> entrySearchTerms(String query) =>
    trLower(query).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

/// Kaydın arandığı metinler: açıklama, başlık, durum ve tutar. Tutar hem
/// ekrandaki gibi ("1.250,00 ₺") hem noktasız ("1250,00") yer alır; "1250"
/// yazan da bulur. Tarih bilerek yok: "12" yazan tutar arıyordur.
String entrySearchText(LedgerEntry e, Side me, {bool isPrivate = false}) {
  final amount = e.amount;
  return trLower(
    [
      e.description,
      EntryText.title(e, me),
      EntryText.status(e, me, isPrivate: isPrivate).label,
      amount.format(),
      amount.format(withSymbol: false).replaceAll('.', ''),
      amount.asset.label,
    ].join('\n'),
  );
}

/// Kelime metinde geçiyor mu. Sayıda nokta ondalık da olabilir ("12.5"):
/// virgüllü hâli de denenir.
bool _hasTerm(String text, String term) {
  if (text.contains(term)) return true;
  return RegExp(r'^[0-9.]+$').hasMatch(term) &&
      term.contains('.') &&
      text.contains(term.replaceAll('.', ','));
}

bool entryMatches(
  LedgerEntry e,
  Side me,
  List<String> terms, {
  bool isPrivate = false,
}) {
  if (terms.isEmpty) return true;
  final text = entrySearchText(e, me, isPrivate: isPrivate);
  return terms.every((t) => _hasTerm(text, t));
}

/// Sorguya uyan kayıtlar (sıra korunur).
List<LedgerEntry> searchEntries(
  List<LedgerEntry> entries,
  Side me,
  String query, {
  bool isPrivate = false,
}) {
  final terms = entrySearchTerms(query);
  return [
    for (final e in entries)
      if (entryMatches(e, me, terms, isPrivate: isPrivate)) e,
  ];
}
