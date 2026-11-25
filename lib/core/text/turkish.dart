/// Türkçe büyük harf: Dart'ın `toUpperCase`'i "i"yi "I" yapar, "İ" yapmaz.
String trUpper(String text) =>
    text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// Türkçe küçük harf ("I" → "ı", "İ" → "i").
String trLower(String text) =>
    text.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

/// Ad soyaddan en fazla iki baş harf: "ayşe yılmaz" → "AY".
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p.characters.first).join();
  return letters.isEmpty ? '?' : trUpper(letters);
}

extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}
