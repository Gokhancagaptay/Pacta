// Pacta kodu: kişiyi e-postası olmadan eklemek için 6 karakter.
// Sunucudaki normalizeCode ile aynı kural (functions/src/ledger/contacts.ts).

const _alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
final _codeRe = RegExp('^[$_alphabet]{6}\$');
final _linkRe = RegExp(r'/u/([A-Za-z0-9-]+)');

/// Davet linklerinin adresi (Firebase Hosting).
const inviteHost = 'pacta-76686.web.app';

/// "k7q-3xm", "https://…/u/K7Q3XM" → "K7Q3XM"; geçersizse null.
String? parsePactaCode(String raw) {
  final fromLink = _linkRe.firstMatch(raw)?.group(1) ?? raw;
  final code = fromLink.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  return _codeRe.hasMatch(code) ? code : null;
}

/// Okunaklı yazım: "K7Q-3XM".
String formatPactaCode(String code) =>
    code.length == 6 ? '${code.substring(0, 3)}-${code.substring(3)}' : code;

/// QR'ın ve davetin taşıdığı link.
String inviteLink(String code) => 'https://$inviteHost/u/$code';

/// Paylaşılan davet metni (WhatsApp vb.).
String inviteText(String code) =>
    'Pacta\'da borç-alacak hesabımızı birlikte, karşılıklı onaylı tutalım. '
    'Beni eklemek için bağlantıya dokun: ${inviteLink(code)}\n'
    'Ya da Pacta\'da Kişi ekle > Pacta kodu: ${formatPactaCode(code)}';
