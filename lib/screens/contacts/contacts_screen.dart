import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'contact_analysis_screen.dart';
import '../../services/firestore_service.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    Future<void> showAddContactDialog() async {
      final _nameController = TextEditingController();
      final _emailController = TextEditingController();
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Yeni Kişi Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Ad Soyad'),
              ),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-posta'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                final email = _emailController.text.trim();
                if (name.isNotEmpty && email.isNotEmpty) {
                  // Kullanıcı var mı kontrol et
                  final userQuery = await FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: email)
                      .limit(1)
                      .get();
                  if (userQuery.docs.isNotEmpty) {
                    final userId = userQuery.docs.first.id;
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUserId)
                        .collection('savedContacts')
                        .add({'adSoyad': name, 'email': email, 'uid': userId});
                    Navigator.pop(context);
                  } else {
                    // Kullanıcı yoksa ekleme ve uyarı göster
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Bu e-posta ile kayıtlı bir kullanıcı bulunamadı. Note modu için kişi eklenemez.',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textMain =
        theme.textTheme.titleLarge?.color ??
        (isDark ? Colors.white : const Color(0xFF1A202C));
    final textSec =
        theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ??
        (isDark ? Colors.white70 : Colors.grey[600]);
    final iconMain = isDark ? Colors.white : const Color(0xFF1A202C);
    final iconDelete = Colors.redAccent;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Kişilerim',
          style: TextStyle(
            color: textMain,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconMain),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: iconMain, size: 28),
            tooltip: 'Kişi Ekle',
            onPressed: showAddContactDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('savedContacts')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Kayıtlı kişi bulunamadı.',
                style: TextStyle(fontSize: 16, color: textSec),
              ),
            );
          }
          final contacts = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index].data() as Map<String, dynamic>;
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: cardColor,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDark
                        ? Colors.blueGrey[800]
                        : Colors.blueGrey[100],
                    child: Text(
                      (contact['adSoyad'] ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textMain,
                      ),
                    ),
                  ),
                  title: Text(
                    contact['adSoyad'] ?? '-',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: textMain,
                    ),
                  ),
                  subtitle: Text(
                    contact['email'] ?? '-',
                    style: TextStyle(
                      color: textSec,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.bar_chart_outlined,
                          color: isDark ? Colors.tealAccent : Colors.blueGrey,
                        ),
                        tooltip: 'Analiz',
                        onPressed: () {
                          final finalContactId =
                              contact['uid'] ??
                              contact['email'] ??
                              contacts[index].id;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContactAnalysisScreen(
                                contactId: finalContactId,
                                contactName: contact['adSoyad'] ?? '-',
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: iconDelete),
                        tooltip: 'Sil',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Kişiyi Sil'),
                              content: const Text(
                                'Bu kişiyi silmek istediğinize emin misiniz?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('İptal'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Sil'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUserId)
                                .collection('savedContacts')
                                .doc(contacts[index].id)
                                .delete();
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () {},
                ),
              );
            },
          );
        },
      ),
    );
  }
}
