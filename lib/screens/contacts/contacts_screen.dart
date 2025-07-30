import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'contact_analysis_screen.dart';
import '../../services/firestore_service.dart';
import 'package:pacta/models/user_model.dart'; // UserModel'i import et

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    void showAddContactSheet() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const _AddContactSheet(),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
            onPressed: showAddContactSheet,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
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
                          // Analiz ekranına yönlendirme
                          // Eğer gerçek bir kullanıcı ise uid'sini, değilse (not kişisi) kendi belge ID'sini kullan
                          final contactIdForAnalysis =
                              contact['uid'] ?? contacts[index].id;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContactAnalysisScreen(
                                contactId: contactIdForAnalysis,
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
                                .doc(FirebaseAuth.instance.currentUser?.uid)
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

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet({Key? key}) : super(key: key);

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  bool _isNoteMode = false;
  bool _isChecking = false;
  final _firestoreService = FirestoreService();

  Future<void> _addContact() async {
    final name = _nameController.text.trim();
    final identifier = _identifierController.text.trim();

    if (name.isEmpty || identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun.')),
      );
      return;
    }

    setState(() => _isChecking = true);

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      setState(() => _isChecking = false);
      return;
    }

    final savedContactsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('savedContacts');

    if (_isNoteMode) {
      // Not modunda, kullanıcıyı aramadan direkt ekle
      await savedContactsRef.add({
        'adSoyad': name,
        'email': identifier, // Eposta, tel veya etiket olabilir
        'uid': null, // Gerçek bir kullanıcı olmadığı için UID null
      });
      Navigator.pop(context); // Sheet'i kapat
    } else {
      // Pacta modunda, kullanıcıyı e-posta ile ara
      final UserModel? user = await _firestoreService.getUserByEmail(
        identifier,
      );

      if (user != null) {
        // Kullanıcı bulundu, kişilere ekle
        await savedContactsRef.add({
          'adSoyad': name,
          'email': identifier,
          'uid': user.uid,
        });
        Navigator.pop(context);
      } else {
        // Kullanıcı bulunamadı, hata göster
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bu e-posta ile kayıtlı kullanıcı bulunamadı. Lütfen kişiyi Pacta\'ya davet edin veya Not Modu\'nda ekleyin.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
    setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yeni Kişi Ekle',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Ad Soyad',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _identifierController,
            decoration: const InputDecoration(
              labelText: 'E-posta',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Not Modu'),
            subtitle: const Text('Kişiyi sadece kendi takibiniz için ekleyin.'),
            value: _isNoteMode,
            onChanged: (value) {
              setState(() {
                _isNoteMode = value;
              });
            },
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isChecking ? null : _addContact,
                child: _isChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Ekle'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
