import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pacta/models/saved_contact_model.dart';
import 'package:pacta/models/user_model.dart';
import 'package:pacta/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

class SavedContactsScreen extends StatefulWidget {
  final String title;
  const SavedContactsScreen({Key? key, this.title = 'Kime Vereceksiniz?'})
    : super(key: key);

  @override
  State<SavedContactsScreen> createState() => _SavedContactsScreenState();
}

class _SavedContactsScreenState extends State<SavedContactsScreen> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _searchTerm = '';
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _showOnlyFavorites = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _searchTerm = _searchController.text.trim());
      }
    });
  }

  Stream<Map<String, List<SavedContactModel>>> _getContactsStream() {
    if (currentUserId == null)
      return Stream.value({'favorites': [], 'others': []});

    final savedContactsStream = _firestoreService.getSavedContactsStream(
      _searchTerm,
    );

    final userFavoritesStream = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
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

  @override
  Widget build(BuildContext context) {
    const Color green = Color(0xFF4ADE80);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textMain = isDark ? Colors.white : Colors.black87;
    final iconMain = isDark ? Colors.white : const Color(0xFF1A202C);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(color: textMain)),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
              color: _showOnlyFavorites ? Colors.redAccent : iconMain,
            ),
            tooltip: 'Sadece Favorileri Göster',
            onPressed: () {
              setState(() {
                _showOnlyFavorites = !_showOnlyFavorites;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Kişi ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<Map<String, List<SavedContactModel>>>(
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
                      style: TextStyle(color: Theme.of(context).disabledColor),
                    ),
                  );
                }

                final favorites = snapshot.data!['favorites']!;
                final others = snapshot.data!['others']!;

                if (_showOnlyFavorites && favorites.isEmpty) {
                  return Center(
                    child: Text(
                      'Favori kişi bulunamadı.',
                      style: TextStyle(color: Theme.of(context).disabledColor),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    if (_showOnlyFavorites)
                      ...favorites.map(
                        (contact) => _buildContactCard(contact, true),
                      )
                    else ...[
                      if (favorites.isNotEmpty) ...[
                        _buildSectionHeader('Favoriler'),
                        ...favorites.map(
                          (contact) => _buildContactCard(contact, true),
                        ),
                      ],
                      if (others.isNotEmpty) ...[
                        if (favorites.isNotEmpty) const SizedBox(height: 20),
                        _buildSectionHeader('Tüm Kişiler'),
                        ...others.map(
                          (contact) => _buildContactCard(contact, false),
                        ),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactSheet,
        backgroundColor: green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildContactCard(SavedContactModel contact, bool isFavorite) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textMain = isDark ? Colors.white : Colors.black87;
    final textSec = isDark ? Colors.white70 : Colors.black54;
    const Color green = Color(0xFF4ADE80);

    return Card(
      elevation: 0,
      color: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: theme.cardColor,
        leading: CircleAvatar(
          backgroundColor: green.withOpacity(0.2),
          child: Text(
            contact.adSoyad.isNotEmpty ? contact.adSoyad[0].toUpperCase() : '?',
            style: const TextStyle(color: green, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          contact.adSoyad,
          style: TextStyle(color: textMain, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(contact.email, style: TextStyle(color: textSec)),
        trailing: IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.redAccent : textSec,
          ),
          onPressed: () {
            _firestoreService.toggleFavoriteContact(contact.id!);
          },
        ),
        onTap: () {
          Navigator.pop(context, contact);
        },
      ),
    );
  }
}

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet({Key? key}) : super(key: key);

  @override
  State<_AddContactSheet> createState() => __AddContactSheetState();
}

class __AddContactSheetState extends State<_AddContactSheet> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isNoteMode = false;
  bool _isChecking = false;
  bool _userExists = false;
  Timer? _debounce;
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _nameController.dispose();
    _emailController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onEmailChanged() {
    if (_isNoteMode) {
      setState(() => _isChecking = false);
      return;
    }
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    setState(() {
      _isChecking = true;
      _userExists = false;
    });
    _debounce = Timer(const Duration(milliseconds: 700), () async {
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        if (mounted) setState(() => _isChecking = false);
        return;
      }
      final user = await _firestoreService.getUserByEmail(email);
      if (mounted) {
        setState(() {
          _isChecking = false;
          _userExists = user != null;
        });
      }
    });
  }

  Future<void> _addContact() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun.')),
      );
      return;
    }

    if (!_isNoteMode && !_userExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Devam etmek için kayıtlı bir kullanıcı girmelisiniz.'),
        ),
      );
      return;
    }

    final user = _isNoteMode
        ? null
        : await _firestoreService.getUserByEmail(email);
    await _firestoreService.addSavedContact(
      SavedContactModel(adSoyad: name, email: email, uid: user?.uid),
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name kişilere eklendi.')));
  }

  @override
  Widget build(BuildContext context) {
    final canAdd =
        _nameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        (_isNoteMode || (_userExists && !_isChecking));

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
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'E-posta',
              border: const OutlineInputBorder(),
              suffixIcon: _isChecking
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _emailController.text.isNotEmpty && !_isNoteMode
                  ? Icon(
                      _userExists ? Icons.check_circle : Icons.error,
                      color: _userExists ? Colors.green : Colors.red,
                    )
                  : null,
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
                _onEmailChanged();
              });
            },
            secondary: const Icon(Icons.note_alt_outlined),
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
                onPressed: canAdd ? _addContact : null,
                child: const Text('Ekle'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
