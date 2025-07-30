import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Ayarlar',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: theme.colorScheme.onBackground),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- Profil Bilgileri ---
          if (user != null) ...[
            _UserProfileHeader(user: user),
            const SizedBox(height: 24),
          ],

          // --- Hesap Bölümü ---
          _SettingsSection(
            title: 'Hesap',
            tiles: [
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'Profili Düzenle',
                onTap: () {
                  // TODO: Profil düzenleme ekranına git
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Genel Ayarlar Bölümü ---
          _SettingsSection(
            title: 'Genel',
            tiles: [
              SwitchListTile(
                title: const Text('Karanlık Mod'),
                value: theme.brightness == Brightness.dark,
                onChanged: (value) {
                  // TODO: Tema değiştirme mantığını ekle (Provider ile)
                },
                secondary: const Icon(Icons.dark_mode_outlined),
              ),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Bildirimler',
                onTap: () {
                  // TODO: Bildirim ayarları ekranına git
                },
              ),
              _SettingsTile(
                icon: Icons.people_outline,
                title: 'Kişilerim / Analiz',
                onTap: () {
                  // TODO: Kişiler/Analiz ekranına git
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Diğer Bölümü ---
          _SettingsSection(
            title: 'Diğer',
            tiles: [
              _SettingsTile(
                icon: Icons.help_outline,
                title: 'Yardım ve Destek',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Hizmet Şartları',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Gizlilik Politikası',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 32),

          // --- Çıkış Yap Butonu ---
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // TODO: Kullanıcıyı giriş ekranına yönlendir
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }
}

// --- Yardımcı Widget'lar ---

class _UserProfileHeader extends StatelessWidget {
  final User user;
  const _UserProfileHeader({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              user.displayName?.isNotEmpty ?? false
                  ? user.displayName![0].toUpperCase()
                  : (user.email?[0].toUpperCase() ?? '?'),
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? 'İsim Belirtilmemiş',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user.email ?? 'E-posta adresi yok',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> tiles;
  const _SettingsSection({Key? key, required this.title, required this.tiles})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0, bottom: 8.0),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: tiles),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    Key? key,
    required this.icon,
    required this.title,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
