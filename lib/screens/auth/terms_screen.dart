import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/legal.dart';
import '../../features/profile/delete_account_page.dart';
import '../../services/auth_service.dart';

/// Kullanım Koşulları'nın güncel sürümü kabul edilmeden uygulamaya
/// geçilmez: Google ile ilk girişte, koşullar değiştiğinde ve koşullardan
/// önce açılmış hesaplarda bir kez görünür. E-postayla kayıtta kabul
/// formda alınır, bu ekran çıkmaz.
class TermsScreen extends StatefulWidget {
  const TermsScreen({
    super.key,
    required this.onAccept,
    this.updated = false,
    this.openPage,
    this.onSignOut,
  });

  /// Kabulü kaydeder (users.termsVersion). Hata fırlatırsa ekranda kalınır.
  final Future<void> Function() onAccept;

  /// Daha önce eski bir sürüm kabul edilmişse metin "güncellendi" der.
  final bool updated;

  /// Testler için; verilmezse sayfa tarayıcıda açılır.
  final void Function(LegalPage page)? openPage;
  final Future<void> Function()? onSignOut;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  void _open(LegalPage page) => widget.openPage != null
      ? widget.openPage!(page)
      : openLegalPage(context, page);

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAccept();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Kaydedilemedi. İnternet bağlantınızı kontrol edip tekrar '
              'deneyin.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pacta;
    final text = Theme.of(context).textTheme;

    Widget point(IconData icon, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: c.credit),
          const SizedBox(width: 12),
          Expanded(child: Text(body, style: const TextStyle(height: 1.4))),
        ],
      ),
    );

    Widget pageLink(LegalPage page) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.description_outlined),
      title: Text(page.title),
      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
      onTap: () => _open(page),
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            Text(
              widget.updated
                  ? 'Koşullarımız güncellendi'
                  : 'Devam etmeden önce',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Pacta\'yı kullanmak için Kullanım Koşulları\'nı kabul etmeniz '
              'gerekir. Kısaca:',
              style: TextStyle(color: c.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            point(
              Icons.menu_book_outlined,
              'Pacta bir kayıt aracıdır: borç vermez, para tutmaz, tahsilat '
              'yapmaz. Kayıtlar tarafların kendi beyanıdır.',
            ),
            point(
              Icons.handshake_outlined,
              'Karşı tarafın aleyhine bir kayıt, o onaylamadan bakiyeye '
              'girmez. Cevap vermemek onay sayılmaz.',
            ),
            point(
              Icons.visibility_outlined,
              'Ortak defterdeki kayıtları ve açıklamaları karşı taraf da '
              'görür. Kişisel verileriniz satılmaz, reklam gösterilmez.',
            ),
            point(
              Icons.person_remove_outlined,
              'Hesabınızı istediğiniz an silebilirsiniz; ortak geçmiş karşı '
              'tarafta adınız gizlenerek saklanır.',
            ),
            const SizedBox(height: 4),
            pageLink(LegalPage.terms),
            pageLink(LegalPage.privacy),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _agreed,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _agreed = v ?? false),
              title: const Text(
                'Kullanım Koşulları\'nı okudum ve kabul ediyorum. 18 '
                'yaşından büyüğüm.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _agreed && !_busy ? _accept : null,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kabul et ve devam et'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => (widget.onSignOut ?? AuthService().signOut)(),
              child: const Text('Çıkış yap'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DeleteAccountPage(),
                      ),
                    ),
              child: Text('Hesabı sil', style: TextStyle(color: c.debt)),
            ),
          ],
        ),
      ),
    );
  }
}
