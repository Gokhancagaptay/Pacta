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
    final size = MediaQuery.of(context).size;
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textMain,
            fontSize: size.width * 0.05,
          ),
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
            padding: EdgeInsets.all(size.width * 0.04),
            children: [
              if (userModel != null) ...[
                _UserProfileHeader(
                  user: userModel,
                  cardBg: cardBg,
                  borderColor: borderColor,
                ),
                SizedBox(height: size.height * 0.03),
              ],

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
              SizedBox(height: size.height * 0.02),

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
              SizedBox(height: size.height * 0.02),

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

              SizedBox(height: size.height * 0.04),

              ElevatedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.white),
                label: Text(
                  'Çıkış Yap',
                  style: TextStyle(
                    fontSize: size.width * 0.045,
                    fontWeight: FontWeight.bold,
                  ),
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
                  minimumSize: Size(double.infinity, size.height * 0.07),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(size.width * 0.045),
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

class _UserProfileHeader extends StatelessWidget {
  final UserModel user;
  final Color cardBg;
  final Color borderColor;
  const _UserProfileHeader({
    required this.user,
    required this.cardBg,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(size.width * 0.045),
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
            radius: size.width * 0.075,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.13),
            child: Text(
              (() {
                final name = (user.adSoyad ?? '').trim();
                if (name.isNotEmpty) return name.substring(0, 1).toUpperCase();
                final mail = (user.email).trim();
                if (mail.isNotEmpty) return mail.substring(0, 1).toUpperCase();
                return '?';
              })(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: size.width * 0.06,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: size.width * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user.adSoyad == null ||
                          (user.adSoyad?.trim().isEmpty ?? true))
                      ? 'İsim Belirtilmemiş'
                      : user.adSoyad!,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: size.width * 0.05,
                  ),
                ),
                Text(
                  user.email.trim().isEmpty
                      ? 'E-posta belirtilmemiş'
                      : user.email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: size.width * 0.038,
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
    required this.title,
    required this.tiles,
    required this.cardBg,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: size.width * 0.03,
            bottom: size.height * 0.01,
            top: size.height * 0.01,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: size.width * 0.04,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(size.width * 0.045),
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
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: size.width * 0.06),
      title: Text(title, style: TextStyle(fontSize: size.width * 0.042)),
      trailing: Icon(Icons.chevron_right, size: size.width * 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size.width * 0.045),
      ),
    );
  }
}
