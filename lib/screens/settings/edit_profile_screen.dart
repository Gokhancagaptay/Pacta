import 'package:flutter/material.dart';
import 'package:pacta/models/user_model.dart';
import 'package:pacta/services/auth_service.dart';
import 'package:pacta/services/firestore_service.dart';
import 'package:pacta/screens/auth/giris_ekrani.dart';
import 'package:pacta/screens/settings/change_password_screen.dart';
import 'package:pacta/screens/settings/notification_settings_screen.dart';
// import 'package:image_picker/image_picker.dart'; // Add this for image picking
// import 'dart:io';

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
  // File? _image;

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

  // Future<void> _pickImage() async {
  //   final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
  //   if (pickedFile != null) {
  //     setState(() {
  //       _image = File(pickedFile.path);
  //     });
  //   }
  // }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final updatedData = <String, dynamic>{};
        if (_nameController.text != widget.user.adSoyad) {
          updatedData['adSoyad'] = _nameController.text;
        }
        if (_emailController.text != widget.user.email) {
          // You might want to add email validation logic here
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          'Profili Düzenle',
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 24),
              _buildSectionTitle('Profil Bilgileri'),
              _buildProfileInfoCard(),
              const SizedBox(height: 24),
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
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
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

  Widget _buildProfileHeader() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.green.shade100,
                // backgroundImage: _image != null ? FileImage(_image!) : null,
                child:
                    // _image == null
                    //     ?
                    Text(
                      widget.user.adSoyad?.isNotEmpty ?? false
                          ? widget.user.adSoyad![0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                // : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  // onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _nameController.text,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _emailController.text,
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildProfileInfoCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      leading: Icon(icon, color: Colors.green.shade600),
      title: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          labelStyle: TextStyle(color: Colors.grey.shade600),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
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
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: textColor ?? Colors.grey.shade700),
      title: Text(title, style: TextStyle(color: textColor)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.withOpacity(0.5)),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white),
              )
            : const Text('Değişiklikleri Kaydet'),
      ),
    );
  }
}
