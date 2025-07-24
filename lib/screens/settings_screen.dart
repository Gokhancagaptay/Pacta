import 'package:flutter/material.dart';
import 'package:pacta/services/auth_service.dart';
import 'package:pacta/screens/auth/giris_ekrani.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Size size = MediaQuery.of(context).size;
    final double width = size.width;
    final double height = size.height;
    final cardColor = isDark ? const Color(0xFF23262F) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF111827);
    final green = const Color(0xFF4ADE80);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ayarlar',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: width * 0.055,
            color: textMain,
          ),
        ),
        centerTitle: true,
        backgroundColor: cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textMain, size: width * 0.07),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.08),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(
                  Icons.logout,
                  color: Colors.white,
                  size: width * 0.07,
                ),
                label: Text(
                  'Çıkış Yap',
                  style: TextStyle(
                    fontSize: width * 0.05,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, height * 0.07),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const GirisEkrani()),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
