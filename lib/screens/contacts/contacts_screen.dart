import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pacta/models/saved_contact_model.dart';
import 'package:pacta/models/user_model.dart';
import 'package:rxdart/rxdart.dart';
import 'contact_analysis_screen.dart';
import '../../services/firestore_service.dart';
import 'package:pacta/utils/dialog_utils.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  _ContactsScreenState createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  // Kullanıcı ID'sini her kullanımda taze alacağız; başlangıçta null olabilir
  bool _showOnlyFavorites = false;

  Stream<Map<String, List<SavedContactModel>>> _getContactsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream.value({'favorites': [], 'others': []});
    }

    final savedContactsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedContacts')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SavedContactModel.fromFirestore(doc))
              .toList(),
        );

    final userFavoritesStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map(
          (doc) =>
              UserModel.fromMap(
                doc.data() as Map<String, dynamic>,
              ).favoriteContacts ??
              [],
        );

    return Rx.combineLatest2(savedContactsStream, userFavoritesStream, (
      List<SavedContactModel> contacts,
      List<String> favoriteIds,
    ) {
      final favoriteContacts = contacts
          .where((c) => favoriteIds.contains(c.id))
          .toList();
      final otherContacts = contacts
          .where((c) => !favoriteIds.contains(c.id))
          .toList();

      favoriteContacts.sort((a, b) => a.adSoyad.compareTo(b.adSoyad));
      otherContacts.sort((a, b) => a.adSoyad.compareTo(b.adSoyad));

      return {'favorites': favoriteContacts, 'others': otherContacts};
    });
  }

  void _showAddContactSheet() {
    final size = MediaQuery.of(context).size;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (modalContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(modalContext).viewInsets.bottom,
        ),
        child: const _AddContactSheet(),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(size.width * 0.05),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final textMain =
        theme.textTheme.titleLarge?.color ??
        (isDark ? Colors.white : const Color(0xFF1A202C));
    final iconMain = isDark ? Colors.white : const Color(0xFF1A202C);

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
            fontSize: size.width * 0.05,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
              color: _showOnlyFavorites ? Colors.redAccent : iconMain,
              size: size.width * 0.06,
            ),
            tooltip: 'Sadece Favorileri Göster',
            onPressed: () {
              setState(() {
                _showOnlyFavorites = !_showOnlyFavorites;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.add, color: iconMain, size: size.width * 0.07),
            tooltip: 'Kişi Ekle',
            onPressed: _showAddContactSheet,
          ),
        ],
      ),
      body: StreamBuilder<Map<String, List<SavedContactModel>>>(
        stream: _getContactsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData ||
              (snapshot.data!['favorites']!.isEmpty &&
                  snapshot.data!['others']!.isEmpty)) {
            return Center(
              child: Text(
                'Kayıtlı kişi bulunamadı.',
                style: TextStyle(
                  fontSize: size.width * 0.04,
                  color: Theme.of(context).disabledColor,
                ),
              ),
            );
          }
          final favorites = snapshot.data!['favorites']!;
          final others = snapshot.data!['others']!;

          if (_showOnlyFavorites && favorites.isEmpty) {
            return Center(
              child: Text(
                'Favori kişi bulunamadı.',
                style: TextStyle(
                  color: Theme.of(context).disabledColor,
                  fontSize: size.width * 0.04,
                ),
              ),
            );
          }

          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.04,
              vertical: size.height * 0.02,
            ),
            children: [
              if (_showOnlyFavorites)
                ...favorites.map((contact) => _buildContactCard(contact, true))
              else ...[
                if (favorites.isNotEmpty) ...[
                  _buildSectionHeader('Favoriler'),
                  ...favorites.map(
                    (contact) => _buildContactCard(contact, true),
                  ),
                ],
                if (others.isNotEmpty) ...[
                  if (favorites.isNotEmpty)
                    SizedBox(height: size.height * 0.025),
                  _buildSectionHeader('Tüm Kişiler'),
                  ...others.map((contact) => _buildContactCard(contact, false)),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: EdgeInsets.only(
        bottom: size.height * 0.01,
        left: size.width * 0.01,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: size.width * 0.035,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildContactCard(SavedContactModel contact, bool isFavorite) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final textMain =
        theme.textTheme.titleLarge?.color ??
        (isDark ? Colors.white : const Color(0xFF1A202C));
    final textSec =
        theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ??
        (isDark ? Colors.white70 : Colors.grey[600]);
    final iconDelete = Colors.redAccent;

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: size.height * 0.015),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size.width * 0.03),
      ),
      color: cardColor,
      child: ListTile(
        leading: CircleAvatar(
          radius: size.width * 0.06,
          backgroundColor: isDark ? Colors.blueGrey[800] : Colors.blueGrey[100],
          child: Text(
            (contact.adSoyad)[0].toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textMain,
              fontSize: size.width * 0.04,
            ),
          ),
        ),
        title: Text(
          contact.adSoyad,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: size.width * 0.04,
            color: textMain,
          ),
        ),
        subtitle: Text(
          contact.email,
          style: TextStyle(
            color: textSec,
            fontWeight: FontWeight.normal,
            fontSize: size.width * 0.035,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.redAccent : Colors.grey,
                size: size.width * 0.055,
              ),
              tooltip: isFavorite ? 'Favorilerden Kaldır' : 'Favorilere Ekle',
              onPressed: () {
                _firestoreService.toggleFavoriteContact(contact.id!);
              },
            ),
            IconButton(
              icon: Icon(
                Icons.bar_chart_outlined,
                color: isDark ? Colors.tealAccent : Colors.blueGrey,
                size: size.width * 0.055,
              ),
              tooltip: 'Analiz',
              onPressed: () {
                final contactIdForAnalysis = contact.uid ?? contact.id;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContactAnalysisScreen(
                      contactId: contactIdForAnalysis!,
                      contactName: contact.adSoyad,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: iconDelete,
                size: size.width * 0.055,
              ),
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
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('İptal'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sil'),
                      ),
                    ],
                  ),
                );
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (confirm == true && uid != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('savedContacts')
                      .doc(contact.id!)
                      .delete();
                  DialogUtils.showSuccess(context, 'Kişi silindi.');
                }
              },
            ),
          ],
        ),
        onTap: () {},
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

    try {
      if (_isNoteMode) {
        await savedContactsRef.add({
          'adSoyad': name,
          'email': identifier,
          'uid': null,
        });
        Navigator.pop(context);
      } else {
        final UserModel? user = await _firestoreService.getUserByEmail(
          identifier,
        );

        if (user != null) {
          await savedContactsRef.add({
            'adSoyad': name,
            'email': identifier,
            'uid': user.uid,
          });
          Navigator.pop(context);
        } else {
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
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: EdgeInsets.all(size.width * 0.05),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yeni Kişi Ekle',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: size.width * 0.06),
          ),
          SizedBox(height: size.height * 0.025),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Ad Soyad',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: size.height * 0.015),
          TextField(
            controller: _identifierController,
            decoration: const InputDecoration(
              labelText: 'E-posta',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: size.height * 0.015),
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
          SizedBox(height: size.height * 0.025),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              SizedBox(width: size.width * 0.03),
              ElevatedButton(
                onPressed: _isChecking ? null : _addContact,
                child: _isChecking
                    ? SizedBox(
                        width: size.width * 0.05,
                        height: size.width * 0.05,
                        child: const CircularProgressIndicator(strokeWidth: 2),
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
