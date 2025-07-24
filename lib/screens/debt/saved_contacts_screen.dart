import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pacta/models/saved_contact_model.dart';
import 'package:pacta/services/firestore_service.dart';
import 'amount_input_screen.dart';

class SavedContactsScreen extends StatefulWidget {
  final String title;
  const SavedContactsScreen({Key? key, this.title = 'Kime Verdiniz?'})
    : super(key: key);

  @override
  State<SavedContactsScreen> createState() => _SavedContactsScreenState();
}

class _SavedContactsScreenState extends State<SavedContactsScreen>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  final _currentUser = FirebaseAuth.instance.currentUser!;
  List<SavedContactModel> _contacts = [];
  List<String> _favorites = [];
  bool _loading = true;
  String _search = '';
  int _tabIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadContacts();
  }

  void _loadContacts() async {
    setState(() => _loading = true);
    final contacts = await _firestoreService.getSavedContacts(_currentUser.uid);
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  void _toggleFavorite(String uid) {
    setState(() {
      if (_favorites.contains(uid)) {
        _favorites.remove(uid);
      } else {
        _favorites.add(uid);
      }
    });
  }

  void _addContactModal() async {
    String adSoyad = '';
    String contactInput = '';
    String? foundUserId;
    bool userExists = false;
    bool checked = false;
    bool loading = false;
    String? errorMsg;
    bool noteMode = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yeni Kişi Ekle',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Ad Soyad'),
                    onChanged: (v) => adSoyad = v,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'E-posta, Telefon veya Etiket',
                      suffixIcon: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : checked
                          ? (userExists
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : const Icon(Icons.error, color: Colors.red))
                          : null,
                    ),
                    keyboardType: TextInputType.text,
                    onChanged: (v) async {
                      contactInput = v;
                      foundUserId = null;
                      if (noteMode) return;
                      setModalState(() {
                        loading = true;
                        checked = false;
                        errorMsg = null;
                      });
                      final user = await _firestoreService.searchUserByAny(
                        contactInput,
                      );
                      setModalState(() {
                        userExists = user != null;
                        foundUserId = user?.uid;
                        checked = true;
                        loading = false;
                        errorMsg = userExists
                            ? null
                            : 'Kayıtlı bir kullanıcı bulunamadı.';
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Switch(
                        value: noteMode,
                        onChanged: (val) => setModalState(() {
                          noteMode = val;
                          if (noteMode) {
                            errorMsg = null;
                            checked = false;
                            userExists = false;
                            foundUserId = null;
                          }
                        }),
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                      const Text('Not Modu (Kendine özel kişi ekle)'),
                    ],
                  ),
                  if (errorMsg != null && !noteMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        errorMsg!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('İptal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              (noteMode &&
                                      adSoyad.isNotEmpty &&
                                      contactInput.isNotEmpty) ||
                                  (!noteMode &&
                                      userExists &&
                                      adSoyad.isNotEmpty)
                              ? () async {
                                  final contact = SavedContactModel(
                                    uid: noteMode
                                        ? contactInput
                                        : (foundUserId ?? contactInput),
                                    adSoyad: adSoyad,
                                    email: contactInput,
                                  );
                                  await _firestoreService.addSavedContact(
                                    _currentUser.uid,
                                    contact,
                                  );
                                  _loadContacts();
                                  Navigator.pop(context, contact.uid);
                                }
                              : null,
                          child: const Text('Ekle'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    ).then((selectedContact) {
      if (selectedContact != null && selectedContact is String) {
        Navigator.pop(context, selectedContact);
      }
    });
  }

  List<SavedContactModel> get _filteredContacts {
    final list = _tabIndex == 0
        ? _contacts
        : _contacts.where((c) => _favorites.contains(c.uid)).toList();
    if (_search.isEmpty) return list;
    return list
        .where(
          (c) =>
              c.adSoyad.toLowerCase().contains(_search.toLowerCase()) ||
              c.email.toLowerCase().contains(_search.toLowerCase()),
        )
        .toList();
  }

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
          widget.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: width * 0.05,
            color: textMain,
          ),
        ),
        centerTitle: true,
        backgroundColor: cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textMain, size: width * 0.07),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                width * 0.04,
                height * 0.02,
                width * 0.04,
                0,
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Kişi ara',
                  hintStyle: TextStyle(
                    fontSize: width * 0.042,
                    color: textMain.withOpacity(0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: width * 0.06,
                    color: textMain.withOpacity(0.7),
                  ),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                style: TextStyle(fontSize: width * 0.045, color: textMain),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            SizedBox(height: height * 0.01),
            TabBar(
              controller: _tabController,
              onTap: (i) => setState(() => _tabIndex = i),
              indicatorColor: green,
              labelColor: green,
              unselectedLabelColor: textMain.withOpacity(0.5),
              labelStyle: TextStyle(
                fontSize: width * 0.045,
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(text: 'Tüm Kişiler'),
                Tab(text: 'Favoriler'),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredContacts.isEmpty
                  ? Center(
                      child: Text(
                        'Kişi bulunamadı.',
                        style: TextStyle(
                          fontSize: width * 0.045,
                          color: textMain.withOpacity(0.7),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(vertical: height * 0.01),
                      itemCount: _filteredContacts.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: height * 0.01),
                      itemBuilder: (context, index) {
                        final contact = _filteredContacts[index];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: width * 0.06,
                            backgroundColor: green.withOpacity(0.15),
                            child: Text(
                              contact.adSoyad.isNotEmpty
                                  ? contact.adSoyad[0]
                                  : '?',
                              style: TextStyle(
                                fontSize: width * 0.06,
                                color: green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            contact.adSoyad,
                            style: TextStyle(
                              color: textMain,
                              fontSize: width * 0.045,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            contact.email,
                            style: TextStyle(
                              fontSize: width * 0.035,
                              color: textMain.withOpacity(0.7),
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              _favorites.contains(contact.uid)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: _favorites.contains(contact.uid)
                                  ? Colors.red
                                  : textMain.withOpacity(0.5),
                              size: width * 0.065,
                            ),
                            onPressed: () => _toggleFavorite(contact.uid),
                            tooltip: _favorites.contains(contact.uid)
                                ? 'Favorilerden çıkar'
                                : 'Favorilere ekle',
                          ),
                          onTap: () {
                            Navigator.pop(context, contact.uid);
                          },
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: width * 0.03,
                            vertical: height * 0.006,
                          ),
                          minVerticalPadding: height * 0.006,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContactModal,
        backgroundColor: green,
        child: Icon(Icons.add, color: Colors.white, size: width * 0.08),
        tooltip: 'Yeni kişi ekle',
      ),
    );
  }
}
