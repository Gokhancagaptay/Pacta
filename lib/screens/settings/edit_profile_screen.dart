import 'package:flutter/material.dart';
import 'package:pacta/models/user_model.dart';
import 'package:pacta/services/auth_service.dart';
import 'package:pacta/services/firestore_service.dart';
import 'package:pacta/screens/auth/giris_ekrani.dart';
import 'package:pacta/screens/settings/change_password_screen.dart';
import 'package:pacta/screens/settings/notification_settings_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  const EditProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.adSoyad);
    _emailController = TextEditingController(text: widget.user.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final updatedData = <String, dynamic>{};
        if (_nameController.text != widget.user.adSoyad) {
          updatedData['adSoyad'] = _nameController.text;
        }
        if (_emailController.text != widget.user.email) {
          updatedData['email'] = _emailController.text;
        }

        if (updatedData.isNotEmpty) {
          await _firestoreService.updateUser(widget.user.uid, updatedData);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil başarıyla güncellendi!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Bir hata oluştu: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF181A20) : const Color(0xFFF7F8FC);
    final textMain = isDark ? Colors.white : const Color(0xFF1A202C);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Profili Düzenle',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textMain,
            fontSize: size.width * 0.05,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textMain),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(),
              SizedBox(height: size.height * 0.03),
              _buildSectionTitle('Profil Bilgileri'),
              _buildProfileInfoCard(),
              SizedBox(height: size.height * 0.03),
              _buildSectionTitle('Güvenlik ve Diğer Ayarlar'),
              _buildSettingsCard(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildSaveButton(),
    );
  }

  Widget _buildSectionTitle(String title) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: EdgeInsets.only(
        left: size.width * 0.02,
        bottom: size.height * 0.01,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          fontSize: size.width * 0.03,
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final size = MediaQuery.of(context).size;
    final textMain = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A202C);
    return Column(
      children: [
        SizedBox(height: size.height * 0.02),
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: size.width * 0.125,
                backgroundColor: Colors.green.shade100,
                child: Text(
                  widget.user.adSoyad?.isNotEmpty ?? false
                      ? widget.user.adSoyad![0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: size.width * 0.1,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  child: CircleAvatar(
                    radius: size.width * 0.045,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: size.width * 0.05,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: size.height * 0.02),
        Text(
          _nameController.text,
          style: TextStyle(
            fontSize: size.width * 0.055,
            fontWeight: FontWeight.bold,
            color: textMain,
          ),
        ),
        SizedBox(height: size.height * 0.005),
        Text(
          _emailController.text,
          style: TextStyle(
            fontSize: size.width * 0.04,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfoCard() {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF23262F) : Colors.white;

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size.width * 0.03),
      ),
      child: Column(
        children: [
          _buildTextField(
            controller: _nameController,
            icon: Icons.person_outline,
            label: 'Ad Soyad',
          ),
          const Divider(height: 1, indent: 56),
          _buildTextField(
            controller: _emailController,
            icon: Icons.mail_outline,
            label: 'E-posta',
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
  }) {
    final size = MediaQuery.of(context).size;
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
      leading: Icon(
        icon,
        color: Colors.green.shade600,
        size: size.width * 0.06,
      ),
      title: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: size.width * 0.04,
          ),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildSettingsCard() {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF23262F) : Colors.white;
    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size.width * 0.03),
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.lock_outline,
            title: 'Şifreyi Değiştir',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Bildirim Ayarları',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingsTile(
            icon: Icons.logout,
            title: 'Çıkış Yap',
            textColor: Colors.red,
            onTap: () async {
              await _authService.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const GirisEkrani()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: textColor ?? defaultColor,
        size: size.width * 0.06,
      ),
      title: Text(
        title,
        style: TextStyle(color: textColor, fontSize: size.width * 0.042),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey.withOpacity(0.5),
        size: size.width * 0.06,
      ),
    );
  }

  Widget _buildSaveButton() {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        size.width * 0.04,
        size.width * 0.04,
        size.width * 0.04,
        MediaQuery.of(context).padding.bottom + size.height * 0.02,
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, size.height * 0.065),
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontSize: size.width * 0.04,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: _isLoading
            ? SizedBox(
                height: size.width * 0.06,
                width: size.width * 0.06,
                child: const CircularProgressIndicator(color: Colors.white),
              )
            : const Text('Değişiklikleri Kaydet'),
      ),
    );
  }
}
