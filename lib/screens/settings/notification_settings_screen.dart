import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pacta/models/user_model.dart';
import 'package:pacta/services/firestore_service.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ayarlar güncellenirken bir hata oluştu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Bildirim Ayarları',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onBackground,
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
                            iconColor: Colors.blue.shade700,
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
                            iconColor: Colors.green.shade700,
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
                            iconColor: Colors.orange.shade700,
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
                            iconColor: Colors.purple.shade700,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 8.0, 16.0, 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSettingsGroupCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        color: Theme.of(context).colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: CircleAvatar(
        radius: 16,
        backgroundColor: iconColor.withOpacity(0.1),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: iconColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
    );
  }
}
