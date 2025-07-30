import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pacta/models/saved_contact_model.dart';
import 'package:pacta/models/user_model.dart';
import 'package:pacta/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavedContactsScreen extends StatefulWidget {
  final String title;
  const SavedContactsScreen({Key? key, this.title = 'Kime Vereceksiniz?'})
    : super(key: key);

  @override
  State<SavedContactsScreen> createState() => _SavedContactsScreenState();
}

class _SavedContactsScreenState extends State<SavedContactsScreen>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  late TabController _tabController;
  Timer? _debounce;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    final textSec = isDark ? Colors.white70 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF2D3748) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(color: textMain)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: green,
          labelColor: green,
          unselectedLabelColor: textSec,
          tabs: const [
            Tab(text: 'Tüm Kişiler'),
            Tab(text: 'Favoriler'),
          ],
        ),
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
            child: StreamBuilder<UserModel?>(
              stream: _firestoreService.getUserStream(
                FirebaseAuth.instance.currentUser!.uid,
              ),
              builder: (context, userSnapshot) {
                final favoriteIds = userSnapshot.data?.favoriteContacts ?? [];
                return StreamBuilder<List<SavedContactModel>>(
                  stream: _firestoreService.getSavedContactsStream(_searchTerm),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text(
                          'Kişi bulunamadı.',
                          style: TextStyle(color: textSec),
                        ),
                      );
                    }

                    final allContacts = snapshot.data!;
                    final favoriteContacts = allContacts
                        .where((c) => favoriteIds.contains(c.id))
                        .toList();

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        // Tüm Kişiler
                        _ContactList(
                          contacts: allContacts,
                          favoriteIds: favoriteIds,
                        ),
                        // Favoriler
                        _ContactList(
                          contacts: favoriteContacts,
                          favoriteIds: favoriteIds,
                        ),
                      ],
                    );
                  },
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
}

class _ContactList extends StatelessWidget {
  const _ContactList({
    Key? key,
    required this.contacts,
    required this.favoriteIds,
  }) : super(key: key);

  final List<SavedContactModel> contacts;
  final List<String> favoriteIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textMain = isDark ? Colors.white : Colors.black87;
    final textSec = isDark ? Colors.white70 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF2D3748) : Colors.white;
    const Color green = Color(0xFF4ADE80);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: contacts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final isFavorite = favoriteIds.contains(contact.id);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: green.withOpacity(0.2),
            child: Text(
              contact.adSoyad.isNotEmpty
                  ? contact.adSoyad[0].toUpperCase()
                  : '?',
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
              FirestoreService().toggleFavoriteContact(contact.id!);
            },
          ),
          onTap: () {
            Navigator.pop(context, contact.email);
          },
        );
      },
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
