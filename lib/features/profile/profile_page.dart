import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/ui/widgets.dart';
import '../../providers/theme_provider.dart';
import '../../screens/settings/change_password_screen.dart';
import '../../screens/settings/edit_profile_screen.dart';
import '../../screens/settings/notification_settings_screen.dart';
import '../../services/auth_service.dart';
import '../ledger/application/providers.dart';
import 'profile_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pacta;
    final user = ref.watch(userProfileProvider).valueOrNull;
    final themeMode = ref.watch(themeProvider);
    final isPasswordUser =
        ref.watch(authUserProvider).valueOrNull?.providerData.any(
          (p) => p.providerId == 'password',
        ) ??
        false;
    final name = (user?.adSoyad?.trim().isNotEmpty ?? false) ? user!.adSoyad! : 'Adınızı ekleyin';

    Widget link(IconData icon, String title, VoidCallback onTap, {Color? color}) =>
        ListTile(
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
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(user?.email ?? '', style: TextStyle(color: c.muted)),
                    ],
                  ),
                ),
                if (user != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => EditProfileScreen(user: user)),
                    ),
                    child: const Text('Düzenle'),
                  ),
              ],
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
                    MaterialPageRoute<void>(builder: (_) => const NotificationSettingsScreen()),
                  ),
                ),
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
                          ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
                          ButtonSegment(value: ThemeMode.light, label: Text('Açık')),
                          ButtonSegment(value: ThemeMode.dark, label: Text('Koyu')),
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
                      MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen()),
                    ),
                  ),
                  const Divider(indent: 56),
                ],
                link(
                  Icons.logout_rounded,
                  'Çıkış yap',
                  () => AuthService().signOut(),
                  color: c.debt,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
