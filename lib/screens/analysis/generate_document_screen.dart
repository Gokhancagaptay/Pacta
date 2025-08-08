import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pacta/utils/dialog_utils.dart';
import 'package:intl/intl.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:pacta/models/user_model.dart';
import 'package:pacta/services/firestore_service.dart';
import 'package:pacta/widgets/custom_date_range_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum DocumentType { approved, notes, all }

class GenerateDocumentScreen extends StatefulWidget {
  final String? selectedContactId;
  final String? selectedContactName;

  const GenerateDocumentScreen({
    Key? key,
    this.selectedContactId,
    this.selectedContactName,
  }) : super(key: key);

  @override
  _GenerateDocumentScreenState createState() => _GenerateDocumentScreenState();
}

class _GenerateDocumentScreenState extends State<GenerateDocumentScreen> {
  DocumentType _documentType = DocumentType.all;
  DateTimeRange? _selectedDateRange;
  bool _isLoading = false;
  bool _isLoadingContacts = true;

  List<UserModel> _allContacts = [];
  List<String> _favoriteContactIds = [];
  List<String> _selectedContactIds = [];
  bool _isAllUsersSelected = true;
  String _userSelectionText = 'Tüm Kullanıcılar';
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _fetchContactsAndFavorites();
    if (widget.selectedContactId != null &&
        widget.selectedContactName != null) {
      _isAllUsersSelected = false;
      _selectedContactIds = [widget.selectedContactId!];
      _userSelectionText = widget.selectedContactName!;
    }
  }

  Future<void> _fetchContactsAndFavorites() async {
    if (mounted) setState(() => _isLoadingContacts = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoadingContacts = false);
      return;
    }

    try {
      // 1. Fetch the current user's document to get favorite IDs
      final userDocSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final favoriteIds =
          userDocSnapshot.exists &&
              userDocSnapshot.data()!.containsKey('favoriteContacts')
          ? List<String>.from(userDocSnapshot.data()!['favoriteContacts'])
          : <String>[];

      // 2. Fetch the saved contacts subcollection
      final savedContactsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('savedContacts')
          .get();

      if (savedContactsSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _allContacts = [];
            _favoriteContactIds = [];
            _isLoadingContacts = false;
          });
        }
        return;
      }

      // 3. Process saved contacts
      final List<UserModel> allFetchedContacts = [];
      final List<String> registeredContactUids = [];
      final Map<String, Map<String, dynamic>> savedContactsData = {};

      for (final doc in savedContactsSnapshot.docs) {
        final data = doc.data();
        savedContactsData[doc.id] = data;
        final uid = data['uid'] as String?;
        if (uid != null) {
          registeredContactUids.add(uid);
        } else {
          // Add Note-Mode contacts directly
          allFetchedContacts.add(
            UserModel(
              uid: doc.id, // Use savedContact doc.id as the main identifier
              adSoyad: data['adSoyad'] ?? 'İsimsiz',
              email: data['email'] ?? 'E-postasız',
            ),
          );
        }
      }

      // 4. Fetch profiles for registered users
      if (registeredContactUids.isNotEmpty) {
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: registeredContactUids)
            .get();

        final Map<String, UserModel> fetchedUsersByUid = {
          for (var u in usersSnapshot.docs) u.id: UserModel.fromMap(u.data()),
        };

        savedContactsData.forEach((docId, savedData) {
          final uid = savedData['uid'] as String?;
          if (uid != null && fetchedUsersByUid.containsKey(uid)) {
            final user = fetchedUsersByUid[uid]!;
            allFetchedContacts.add(
              UserModel(
                uid:
                    docId, // Critically, use the savedContact docId as the identifier
                adSoyad: user.adSoyad,
                email: user.email,
              ),
            );
          }
        });
      }

      if (mounted) {
        setState(() {
          _allContacts = allFetchedContacts;
          _favoriteContactIds = favoriteIds;
          _isLoadingContacts = false;
        });
      }
    } catch (e) {
      print("Error fetching contacts and favorites: $e");
      if (mounted) {
        setState(() {
          _isLoadingContacts = false;
        });
      }
    }
  }

  String get _dateRangeText {
    if (_selectedDateRange == null) {
      return 'Tarih Aralığı Seçin';
    } else {
      final start = DateFormat('dd.MM.yyyy').format(_selectedDateRange!.start);
      final end = DateFormat('dd.MM.yyyy').format(_selectedDateRange!.end);
      return '$start - $end';
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showCustomDateRangePicker(
      context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Belge için tarih aralığı seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Future<void> _showUserSelectionDialog() async {
    List<String> tempSelectedIds = List.from(_selectedContactIds);
    bool tempSelectAll = _isAllUsersSelected;

    await showDialog(
      context: context,
      builder: (context) {
        final favoriteContacts = _allContacts
            .where((c) => _favoriteContactIds.contains(c.uid))
            .toList();
        final otherContacts = _allContacts
            .where((c) => !_favoriteContactIds.contains(c.uid))
            .toList();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildContactCheckbox(UserModel contact) {
              return CheckboxListTile(
                title: Text(contact.adSoyad ?? 'İsimsiz'),
                subtitle: Text(contact.email),
                value: tempSelectedIds.contains(contact.uid),
                onChanged: (bool? value) {
                  setDialogState(() {
                    if (value == true) {
                      tempSelectedIds.add(contact.uid);
                      tempSelectAll = false;
                    } else {
                      tempSelectedIds.remove(contact.uid);
                    }
                  });
                },
              );
            }

            return AlertDialog(
              title: const Text('Kullanıcı Seç'),
              contentPadding: const EdgeInsets.only(top: 12.0),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        title: const Text('Tüm Kullanıcılar'),
                        value: tempSelectAll,
                        onChanged: (bool? value) {
                          setDialogState(() {
                            tempSelectAll = value ?? false;
                            if (tempSelectAll) {
                              tempSelectedIds.clear();
                            }
                          });
                        },
                      ),
                      if (favoriteContacts.isNotEmpty) ...[
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Favoriler',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        ...favoriteContacts.map(buildContactCheckbox),
                      ],
                      if (otherContacts.isNotEmpty) ...[
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Tüm Kişiler',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        ...otherContacts.map(buildContactCheckbox),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isAllUsersSelected = tempSelectAll;
                      _selectedContactIds = tempSelectedIds;

                      if (_isAllUsersSelected) {
                        _userSelectionText = 'Tüm Kullanıcılar';
                      } else {
                        if (_selectedContactIds.isEmpty) {
                          _isAllUsersSelected = true;
                          _userSelectionText = 'Tüm Kullanıcılar';
                        } else if (_selectedContactIds.length == 1) {
                          _userSelectionText =
                              _allContacts
                                  .firstWhere(
                                    (c) => c.uid == _selectedContactIds.first,
                                    orElse: () => UserModel(
                                      uid: '',
                                      email: '',
                                      adSoyad: 'Bilinmeyen',
                                    ),
                                  )
                                  .adSoyad ??
                              'İsimsiz';
                        } else {
                          _userSelectionText =
                              '${_selectedContactIds.length} kullanıcı seçildi';
                        }
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Tamam'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateDocument() async {
    if (_selectedDateRange == null) {
      DialogUtils.showWarning(context, 'Lütfen bir tarih aralığı seçin.');
      return;
    }
    if (!_isAllUsersSelected && _selectedContactIds.isEmpty) {
      DialogUtils.showWarning(context, 'Lütfen en az bir kullanıcı seçin.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final transactions = await _fetchTransactions();
      final pdf = await _createPdf(transactions);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      DialogUtils.showError(
        context,
        'Belge oluşturulurken bir hata oluştu: $e',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTransactions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    Query query = FirebaseFirestore.instance.collection('debts');

    if (!_isAllUsersSelected) {
      final filterIds = [..._selectedContactIds, uid];
      query = query.where(
        Filter.or(
          Filter('borcluId', whereIn: filterIds),
          Filter('alacakliId', whereIn: filterIds),
        ),
      );
    } else {
      query = query.where(
        Filter.or(
          Filter('borcluId', isEqualTo: uid),
          Filter('alacakliId', isEqualTo: uid),
        ),
      );
    }

    if (_documentType != DocumentType.all) {
      query = query.where(
        'status',
        isEqualTo: _documentType == DocumentType.approved ? 'approved' : 'note',
      );
    }

    final querySnapshot = await query.get();
    List<Map<String, dynamic>> transactions = querySnapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    if (!_isAllUsersSelected) {
      transactions = transactions.where((t) {
        final p1 = t['borcluId'];
        final p2 = t['alacakliId'];
        return (_selectedContactIds.contains(p1) && p2 == uid) ||
            (_selectedContactIds.contains(p2) && p1 == uid);
      }).toList();
    }

    return transactions.where((t) {
      final timestamp = t['islemTarihi'] as Timestamp?;
      if (timestamp == null) return false;
      final date = timestamp.toDate();
      return date.isAfter(
            _selectedDateRange!.start.subtract(const Duration(days: 1)),
          ) &&
          date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
    }).toList();
  }

  Future<pw.Document> _createPdf(
    List<Map<String, dynamic>> transactions,
  ) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final currentUser = await _firestoreService
        .getUserStream(FirebaseAuth.instance.currentUser!.uid)
        .first;
    final contactNames = await Future.wait(
      _selectedContactIds.map((id) => _firestoreService.getUserNameById(id)),
    );
    final selectionText = _isAllUsersSelected
        ? 'Tüm Kullanıcılar'
        : contactNames.join(', ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildHeader(font, boldFont, currentUser?.adSoyad, selectionText),
          _buildTable(transactions, font, boldFont),
          _buildSummary(transactions, font, boldFont),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(
    pw.Font font,
    pw.Font boldFont,
    String? currentUserName,
    String selectionText,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'İşlem Raporu',
          style: pw.TextStyle(font: boldFont, fontSize: 24),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Raporu Oluşturan: ${currentUserName ?? ''}',
          style: pw.TextStyle(font: font, fontSize: 12),
        ),
        pw.Text(
          'Seçilen Kullanıcı(lar): $selectionText',
          style: pw.TextStyle(font: font, fontSize: 12),
        ),
        pw.Text(
          'Tarih Aralığı: $_dateRangeText',
          style: pw.TextStyle(font: font, fontSize: 12),
        ),
        pw.Text(
          'Rapor Tarihi: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
          style: pw.TextStyle(font: font, fontSize: 12),
        ),
        pw.Divider(height: 20, thickness: 1),
      ],
    );
  }

  pw.Widget _buildTable(
    List<Map<String, dynamic>> transactions,
    pw.Font font,
    pw.Font boldFont,
  ) {
    final headers = ['Tarih', 'Açıklama', 'Tutar', 'Durum'];

    return pw.Table.fromTextArray(
      headers: headers,
      data: transactions.map((t) {
        final date = (t['islemTarihi'] as Timestamp).toDate();
        final formattedDate = DateFormat('dd.MM.yyyy').format(date);
        final description = t['aciklama'] ?? 'N/A';
        final amount = t['miktar']?.toStringAsFixed(2) ?? '0.00';
        final status = t['status'] ?? 'N/A';
        return [formattedDate, description, '$amount₺', status];
      }).toList(),
      headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
      cellStyle: pw.TextStyle(font: font),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {2: pw.Alignment.centerRight, 3: pw.Alignment.center},
    );
  }

  pw.Widget _buildSummary(
    List<Map<String, dynamic>> transactions,
    pw.Font font,
    pw.Font boldFont,
  ) {
    final totalBorc = transactions
        .where((t) => t['borcluId'] == FirebaseAuth.instance.currentUser!.uid)
        .fold<double>(0, (sum, t) => sum + (t['miktar'] ?? 0));
    final totalAlacak = transactions
        .where((t) => t['alacakliId'] == FirebaseAuth.instance.currentUser!.uid)
        .fold<double>(0, (sum, t) => sum + (t['miktar'] ?? 0));

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Özet', style: pw.TextStyle(font: boldFont, fontSize: 18)),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Toplam Borç:', style: pw.TextStyle(font: font)),
              pw.Text(
                '${totalBorc.toStringAsFixed(2)}₺',
                style: pw.TextStyle(font: boldFont, color: PdfColors.red),
              ),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Toplam Alacak:', style: pw.TextStyle(font: font)),
              pw.Text(
                '${totalAlacak.toStringAsFixed(2)}₺',
                style: pw.TextStyle(font: boldFont, color: PdfColors.green),
              ),
            ],
          ),
          pw.Divider(height: 10, thickness: 0.5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Net Bakiye:', style: pw.TextStyle(font: boldFont)),
              pw.Text(
                '${(totalAlacak - totalBorc).toStringAsFixed(2)}₺',
                style: pw.TextStyle(
                  font: boldFont,
                  color: (totalAlacak - totalBorc) >= 0
                      ? PdfColors.green
                      : PdfColors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF7F8FC);
    final textColor = isDark ? Colors.white : const Color(0xFF1A202C);
    final primaryColor = Colors.green.shade600;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Belge Oluştur',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: backgroundColor,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Kullanıcı Seçimi'),
            _buildUserSelectionCard(),
            const SizedBox(height: 24),
            _buildSectionTitle('İşlem Türü'),
            _buildDocTypeSelectionCard(),
            const SizedBox(height: 24),
            _buildSectionTitle('Tarih Aralığı'),
            _buildDateRangeCard(),
          ],
        ),
      ),
      bottomNavigationBar: _buildGenerateButton(),
    );
  }

  Widget _buildUserSelectionCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryColor = Colors.green.shade600;
    final secondaryTextColor = isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    return Card(
      elevation: 2.0,
      shadowColor: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: _isLoadingContacts ? null : _showUserSelectionDialog,
        leading: Icon(Icons.people_outline, color: primaryColor),
        title: const Text(
          'Kullanıcılar',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _userSelectionText,
          style: TextStyle(color: secondaryTextColor, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _isLoadingContacts
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryTextColor = isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: secondaryTextColor,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDocTypeSelectionCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

    return Card(
      elevation: 2.0,
      shadowColor: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildRadioListTile(
            'Tüm İşlemler',
            'Onaylı ve not alınmış tüm işlemleri dahil et.',
            DocumentType.all,
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildRadioListTile(
            'Sadece Onaylı İşlemler',
            'Sadece durumu "onaylandı" olan borç ve alacaklar.',
            DocumentType.approved,
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildRadioListTile(
            'Sadece Notlar',
            'Henüz resmiyete dökülmemiş notları listele.',
            DocumentType.notes,
          ),
        ],
      ),
    );
  }

  Widget _buildRadioListTile(
    String title,
    String subtitle,
    DocumentType value,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppColors.darkPrimary
        : AppColors.lightPrimary;
    final secondaryTextColor = isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    return RadioListTile<DocumentType>(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: secondaryTextColor, fontSize: 12),
      ),
      value: value,
      groupValue: _documentType,
      onChanged: (DocumentType? value) {
        if (value != null) {
          setState(() {
            _documentType = value;
          });
        }
      },
      activeColor: primaryColor,
    );
  }

  Widget _buildDateRangeCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryColor = Colors.green.shade600;
    final secondaryTextColor = isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    return Card(
      elevation: 2.0,
      shadowColor: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: _selectDateRange,
        leading: Icon(Icons.calendar_today_outlined, color: primaryColor),
        title: const Text(
          'Tarih Aralığı',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _dateRangeText,
          style: TextStyle(color: secondaryTextColor, fontSize: 14),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: ElevatedButton.icon(
        icon: _isLoading
            ? Container(
                width: 24,
                height: 24,
                padding: const EdgeInsets.all(2.0),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Icon(Icons.picture_as_pdf_outlined),
        label: Text(_isLoading ? 'Oluşturuluyor...' : 'Belgeyi Oluştur'),
        onPressed: _isLoading ? null : _generateDocument,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
