import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pacta/models/user_model.dart';
import 'package:pacta/providers/theme_provider.dart';
import 'package:pacta/screens/auth/giris_ekrani.dart';
import 'package:pacta/screens/contacts/contacts_screen.dart';
import 'package:pacta/screens/notifications/notification_screen.dart';
import 'package:pacta/screens/settings/edit_profile_screen.dart';
import 'package:pacta/services/auth_service.dart';
import 'package:pacta/services/firestore_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final themeMode = ref.watch(themeProvider);
    final isDark = theme.brightness == Brightness.dark;
    final firestoreService = FirestoreService();

    final bg = isDark ? const Color(0xFF181A20) : const Color(0xFFF9FAFB);
    final textMain = isDark ? Colors.white : const Color(0xFF111827);
    final cardBg = isDark ? const Color(0xFF23262F) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          'Ayarlar',
          style: TextStyle(fontWeight: FontWeight.bold, color: textMain),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: bg,
        iconTheme: IconThemeData(color: textMain),
      ),
      body: StreamBuilder<UserModel?>(
        stream: user != null ? firestoreService.getUserStream(user.uid) : null,
        builder: (context, snapshot) {
          final userModel = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- Profil Bilgileri ---
              if (userModel != null) ...[
                _UserProfileHeader(
                  user: userModel,
                  cardBg: cardBg,
                  borderColor: borderColor,
                ),
                const SizedBox(height: 24),
              ],

              // --- Hesap Bölümü ---
              _SettingsSection(
                title: 'Hesap',
                cardBg: cardBg,
                borderColor: borderColor,
                tiles: [
                  _SettingsTile(
                    icon: Icons.person_outline,
                    title: 'Profili Düzenle',
                    onTap: () {
                      if (userModel != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(user: userModel),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Genel Ayarlar Bölümü ---
              _SettingsSection(
                title: 'Genel',
                cardBg: cardBg,
                borderColor: borderColor,
                tiles: [
                  SwitchListTile(
                    title: const Text('Karanlık Mod'),
                    value: themeMode == ThemeMode.dark,
                    onChanged: (value) {
                      ref
                          .read(themeProvider.notifier)
                          .setTheme(value ? ThemeMode.dark : ThemeMode.light);
                    },
                    secondary: const Icon(Icons.dark_mode_outlined),
                  ),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: 'Bildirimler',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.people_outline,
                    title: 'Kişilerim / Analiz',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContactsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Diğer Bölümü ---
              _SettingsSection(
                title: 'Diğer',
                cardBg: cardBg,
                borderColor: borderColor,
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
              ElevatedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'Çıkış Yap',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  await AuthService().signOut();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const GirisEkrani()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF87171),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- Yardımcı Widget'lar ---

class _UserProfileHeader extends StatelessWidget {
  final UserModel user;
  final Color cardBg;
  final Color borderColor;
  const _UserProfileHeader({
    Key? key,
    required this.user,
    required this.cardBg,
    required this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.13),
            child: Text(
              user.adSoyad?.isNotEmpty ?? false
                  ? user.adSoyad![0].toUpperCase()
                  : (user.email[0].toUpperCase()),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.adSoyad ?? 'İsim Belirtilmemiş',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user.email,
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
  final Color cardBg;
  final Color borderColor;
  const _SettingsSection({
    Key? key,
    required this.title,
    required this.tiles,
    required this.cardBg,
    required this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0, bottom: 8.0, top: 8.0),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(color: borderColor, width: 1),
          ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
    );
  }
}
