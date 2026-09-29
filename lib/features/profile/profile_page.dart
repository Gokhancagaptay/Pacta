import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_lock.dart';
import '../../app/theme.dart';
import '../../core/legal.dart';
import '../../core/ui/widgets.dart';
import '../../providers/theme_provider.dart';
import '../../screens/settings/change_password_screen.dart';
import '../../screens/settings/edit_profile_screen.dart';
import '../../screens/settings/notification_settings_screen.dart';
import '../../services/auth_service.dart';
import '../ledger/application/providers.dart';
import '../ledger/presentation/contacts_ui.dart';
import 'delete_account_page.dart';
import 'profile_providers.dart';

/// Kilit anahtarı doğrulama sürerken ikinci isteği açmasın.
bool _lockBusy = false;

/// Çıkış onay ister; onaydan sonra anlıktır (temizlik arkada sürer).
Future<void> _confirmSignOut(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Çıkış yapılsın mı?'),
      content: const Text(
        'Bu telefondaki kayıt önbelleği silinir; tekrar girdiğinizde '
        'yeniden yüklenir.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Çıkış yap'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await AuthService().signOut();
}

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pacta;
    final user = ref.watch(userProfileProvider).valueOrNull;
    final themeMode = ref.watch(themeProvider);
    final isPasswordUser =
        ref
            .watch(authUserProvider)
            .valueOrNull
            ?.providerData
            .any((p) => p.providerId == 'password') ??
        false;
    final name = (user?.adSoyad?.trim().isNotEmpty ?? false)
        ? user!.adSoyad!
        : 'Adınızı ekleyin';

    Widget link(
      IconData icon,
      String title,
      VoidCallback onTap, {
      Color? color,
    }) => ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: Icon(Icons.chevron_right_rounded, color: c.muted),
      onTap: onTap,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SurfaceCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                PersonAvatar(name: name, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(user?.email ?? '', style: TextStyle(color: c.muted)),
                    ],
                  ),
                ),
                if (user != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EditProfileScreen(user: user),
                      ),
                    ),
                    child: const Text('Düzenle'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SurfaceCard(
            child: link(
              Icons.qr_code_2_rounded,
              'Pacta kodum',
              () => openPactaCodePage(context),
            ),
          ),
          const SectionHeader(title: 'Tercihler'),
          SurfaceCard(
            child: Column(
              children: [
                link(
                  Icons.notifications_none_rounded,
                  'Bildirimler',
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  ),
                ),
                if (!kIsWeb) ...[
                  const Divider(indent: 56),
                  SwitchListTile(
                    secondary: const Icon(Icons.lock_outline_rounded),
                    title: const Text('Uygulama kilidi'),
                    subtitle: const Text(
                      'Açarken parmak izi, yüz ya da telefon şifresi sorulur.',
                    ),
                    value: ref.watch(appLockProvider).enabled,
                    onChanged: (value) async {
                      // Doğrulama sürerken ikinci dokunuş yeni istek açmaz.
                      if (_lockBusy) return;
                      _lockBusy = true;
                      final String? error;
                      try {
                        error = await ref
                            .read(appLockProvider.notifier)
                            .setEnabled(value);
                      } finally {
                        _lockBusy = false;
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            error ??
                                (value
                                    ? 'Uygulama kilidi açıldı.'
                                    : 'Uygulama kilidi kapatıldı.'),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const Divider(indent: 56),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.contrast_rounded),
                      const SizedBox(width: 16),
                      const Expanded(child: Text('Görünüm')),
                      SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('Sistem'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Açık'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Koyu'),
                          ),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (s) =>
                            ref.read(themeProvider.notifier).setTheme(s.first),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Hesap'),
          SurfaceCard(
            child: Column(
              children: [
                if (isPasswordUser) ...[
                  link(
                    Icons.lock_outline_rounded,
                    'Şifre değiştir',
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    ),
                  ),
                  const Divider(indent: 56),
                ],
                link(
                  Icons.logout_rounded,
                  'Çıkış yap',
                  () => _confirmSignOut(context),
                ),
                const Divider(indent: 56),
                link(
                  Icons.person_remove_outlined,
                  'Hesabı sil',
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DeleteAccountPage(),
                    ),
                  ),
                  color: c.debt,
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Yasal'),
          SurfaceCard(
            child: Column(
              children: [
                link(
                  Icons.description_outlined,
                  LegalPage.terms.title,
                  () => openLegalPage(context, LegalPage.terms),
                ),
                const Divider(indent: 56),
                link(
                  Icons.privacy_tip_outlined,
                  LegalPage.privacy.title,
                  () => openLegalPage(context, LegalPage.privacy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
