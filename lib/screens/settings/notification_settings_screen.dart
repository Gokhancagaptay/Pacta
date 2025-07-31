import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  _NotificationSettingsScreenState createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _newDebtRequest = true;
  bool _debtStatusChange = true;
  bool _paymentReminder = false;
  bool _promotions = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          'Bildirim Ayarları',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A202C),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFF7F8FC),
        iconTheme: const IconThemeData(color: Color(0xFF1A202C)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('İşlem Bildirimleri'),
            _buildSettingsGroupCard(
              children: [
                _buildSwitchTile(
                  icon: Icons.add_alert_outlined,
                  title: 'Yeni Borç/Alacak Talepleri',
                  subtitle: 'Birisi size borç eklediğinde bildirim alın.',
                  value: _newDebtRequest,
                  onChanged: (value) => setState(() => _newDebtRequest = value),
                ),
                const Divider(height: 1, indent: 68),
                _buildSwitchTile(
                  icon: Icons.sync_alt_outlined,
                  title: 'Durum Değişiklikleri',
                  subtitle:
                      'Borç talebiniz onaylandığında/reddedildiğinde haberdar olun.',
                  value: _debtStatusChange,
                  onChanged: (value) =>
                      setState(() => _debtStatusChange = value),
                ),
                const Divider(height: 1, indent: 68),
                _buildSwitchTile(
                  icon: Icons.calendar_today_outlined,
                  title: 'Ödeme Hatırlatıcıları',
                  subtitle: 'Vadesi yaklaşan ödemeler için hatırlatma alın.',
                  value: _paymentReminder,
                  onChanged: (value) =>
                      setState(() => _paymentReminder = value),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Genel Bildirimler'),
            _buildSettingsGroupCard(
              children: [
                _buildSwitchTile(
                  icon: Icons.campaign_outlined,
                  title: 'Promosyonlar ve Haberler',
                  subtitle:
                      'Uygulama ile ilgili yenilik ve kampanyalardan haberdar olun.',
                  value: _promotions,
                  onChanged: (value) => setState(() => _promotions = value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 8.0, 16.0, 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSettingsGroupCard({required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 2.0,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.green.withOpacity(0.1),
        child: Icon(icon, color: Colors.green.shade700, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.green.shade600,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
    );
  }
}
