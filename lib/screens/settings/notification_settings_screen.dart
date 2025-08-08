import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pacta/models/user_model.dart';
import 'package:pacta/services/firestore_service.dart';
import 'package:pacta/utils/dialog_utils.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  _NotificationSettingsScreenState createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _updateSetting(String key, bool value) async {
    if (_uid == null) return;
    try {
      await _firestoreService.usersRef.doc(_uid).update({
        'notificationSettings.$key': value,
      });
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showError(
        context,
        'Ayarlar güncellenirken bir hata oluştu: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212) // Dark mode arka plan
          : const Color(0xFFF7F8FC), // Light mode arka plan
      appBar: AppBar(
        title: Text(
          'Bildirim Ayarları',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark
                ? const Color(0xFFE1E3E6) // Dark mode beyaz metin
                : const Color(0xFF1A202C), // Light mode koyu metin
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark
            ? const Color(0xFF121212) // Dark mode arka plan
            : const Color(0xFFF7F8FC), // Light mode arka plan
        iconTheme: IconThemeData(
          color: isDark
              ? const Color(0xFFE1E3E6) // Dark mode beyaz ikon
              : const Color(0xFF1A202C), // Light mode koyu ikon
        ),
      ),
      body: _uid == null
          ? const Center(child: Text('Kullanıcı bulunamadı.'))
          : StreamBuilder<UserModel?>(
              stream: _firestoreService.getUserStream(_uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userModel = snapshot.data!;
                final settings = userModel.notificationSettings;

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(context, 'İşlem Bildirimleri'),
                      _buildSettingsGroupCard(
                        context: context,
                        children: [
                          _buildSwitchTile(
                            context: context,
                            icon: Icons.add_alert_outlined,
                            title: 'Yeni Borç/Alacak Talepleri',
                            subtitle:
                                'Birisi size borç eklediğinde bildirim alın.',
                            value: settings.newDebtRequests,
                            onChanged: (value) =>
                                _updateSetting('newDebtRequests', value),
                          ),
                          const Divider(height: 1, indent: 68),
                          _buildSwitchTile(
                            context: context,
                            icon: Icons.sync_alt_outlined,
                            title: 'Durum Değişiklikleri',
                            subtitle:
                                'Talepleriniz onaylandığında/reddedildiğinde haberdar olun.',
                            value: settings.statusChanges,
                            onChanged: (value) =>
                                _updateSetting('statusChanges', value),
                          ),
                          const Divider(height: 1, indent: 68),
                          _buildSwitchTile(
                            context: context,
                            icon: Icons.calendar_today_outlined,
                            title: 'Ödeme Hatırlatıcıları',
                            subtitle:
                                'Vadesi yaklaşan ödemeler için hatırlatma alın.',
                            value: settings.paymentReminders,
                            onChanged: (value) =>
                                _updateSetting('paymentReminders', value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle(context, 'Genel Bildirimler'),
                      _buildSettingsGroupCard(
                        context: context,
                        children: [
                          _buildSwitchTile(
                            context: context,
                            icon: Icons.campaign_outlined,
                            title: 'Promosyonlar ve Haberler',
                            subtitle:
                                'Yenilik ve kampanyalardan haberdar olun.',
                            value: settings.promotionsAndNews,
                            onChanged: (value) =>
                                _updateSetting('promotionsAndNews', value),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 16.0, 16.0, 12.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDark
              ? Colors
                    .grey
                    .shade400 // Dark mode açık gri
              : Colors.grey.shade600, // Light mode koyu gri
          fontSize: 11,
          letterSpacing: 0.5, // Harf aralığı eklendi
        ),
      ),
    );
  }

  Widget _buildSettingsGroupCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 2, // Hafif gölge eklendi
        shadowColor: isDark ? Colors.black54 : Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        color: isDark
            ? const Color(0xFF1E1E1E) // Dark mode koyu kart
            : Colors.white, // Light mode beyaz kart
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SwitchListTile(
      secondary: CircleAvatar(
        radius: 18,
        backgroundColor: isDark
            ? Colors.green.shade800.withOpacity(
                0.3,
              ) // Dark mode koyu yeşil arka plan
            : Colors.green.shade50, // Light mode açık yeşil arka plan
        child: Icon(
          icon,
          color: isDark
              ? Colors
                    .green
                    .shade400 // Dark mode parlak yeşil ikon
              : Colors.green.shade700, // Light mode koyu yeşil ikon
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isDark
              ? const Color(0xFFE1E3E6) // Dark mode beyaz metin
              : const Color(0xFF1A202C), // Light mode koyu metin
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark
              ? Colors
                    .grey
                    .shade400 // Dark mode açık gri
              : Colors.grey.shade600, // Light mode koyu gri
          fontSize: 13,
          height: 1.3,
        ),
      ),
      value: value,
      onChanged: onChanged,
      // Modern switch renk ayarları (tema bağımsız)
      activeColor: const Color(0xFF00C853), // Vurgulu yeşil (açık durum thumb)
      activeTrackColor: isDark
          ? const Color(0xFF2E7D32) // Dark mode koyu yeşil track
          : const Color(0xFFB9F6CA), // Light mode açık yeşil track
      inactiveThumbColor: isDark
          ? const Color(0xFF424242) // Dark mode koyu gri thumb
          : const Color(0xFFCFD8DC), // Light mode açık gri thumb
      inactiveTrackColor: isDark
          ? const Color(0xFF2C2C2C) // Dark mode çok koyu gri track
          : const Color(0xFFECEFF1), // Light mode çok açık gri track
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20.0, // Daha ferah padding
        vertical: 12.0,
      ),
    );
  }
}
