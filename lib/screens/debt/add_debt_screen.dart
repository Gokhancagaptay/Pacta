// lib/screens/debt/add_debt_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pacta/models/debt_model.dart';
import 'package:pacta/models/user_model.dart'; // UserModel'i import et
import 'package:pacta/models/saved_contact_model.dart';
import 'package:pacta/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'saved_contacts_screen.dart';
import 'package:pacta/screens/dashboard/dashboard_screen.dart';

class AddDebtScreen extends StatefulWidget {
  final String? initialPersonEmail;
  final String? initialAmount;
  final bool isPactaAl;
  const AddDebtScreen({
    super.key,
    this.initialPersonEmail,
    this.initialAmount,
    this.isPactaAl = false,
  });

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _personController = TextEditingController();

  final _firestoreService = FirestoreService();
  final _currentUser = FirebaseAuth.instance.currentUser!;

  DateTime? _selectedDueDate;
  bool _showNote = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPersonEmail != null) {
      _personController.text = widget.initialPersonEmail!;
    }
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _personController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  void _saveDebt() async {
    final now = DateTime.now();
    final isNote = _showNote;
    final currentUserId = _currentUser.uid;
    final otherParty =
        widget.initialPersonEmail ?? _personController.text.trim();
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;

    // Kişi seçimi kontrolü
    if (otherParty.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lütfen bir kişi seçin!')));
      return;
    }

    // Miktar kontrolü
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir miktar girin!')),
      );
      return;
    }

    // Not modunda karşı tarafın ID'sini bul
    String actualOtherPartyId = otherParty;
    print('AddDebtScreen: Seçilen kişi: $otherParty');

    if (isNote) {
      try {
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: otherParty)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          actualOtherPartyId = userQuery.docs.first.id;
          print(
            'AddDebtScreen: Not için kullanıcı ID bulundu: $actualOtherPartyId',
          );
        } else {
          // Kullanıcı yoksa email'i ID olarak kullan
          actualOtherPartyId = otherParty;
          print(
            'AddDebtScreen: Kullanıcı bulunamadı, email ID olarak kullanılıyor: $actualOtherPartyId',
          );
        }
      } catch (e) {
        print('AddDebtScreen: Kullanıcı arama hatası: $e');
        actualOtherPartyId = otherParty;
      }
    } else {
      // Normal borç modunda da ID'yi bul
      try {
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: otherParty)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          actualOtherPartyId = userQuery.docs.first.id;
          print(
            'AddDebtScreen: Normal borç için kullanıcı ID bulundu: $actualOtherPartyId',
          );
        } else {
          // Kullanıcı yoksa email'i ID olarak kullan
          actualOtherPartyId = otherParty;
          print(
            'AddDebtScreen: Kullanıcı bulunamadı, email ID olarak kullanılıyor: $actualOtherPartyId',
          );
        }
      } catch (e) {
        print('AddDebtScreen: Kullanıcı arama hatası: $e');
        actualOtherPartyId = otherParty;
      }
    }

    DebtModel newDebt;
    if (isNote) {
      newDebt = DebtModel(
        debtId: null,
        borcluId: currentUserId,
        alacakliId: actualOtherPartyId, // ID kullan
        miktar: amount,
        aciklama: _descriptionController.text,
        islemTarihi: now,
        status: 'note',
        isShared: false,
        requiresApproval: false,
        visibleTo: [
          currentUserId,
          actualOtherPartyId,
        ], // Her iki kullanıcıyı da ekle
        createdBy: currentUserId,
      );
    } else if (widget.isPactaAl) {
      // Pacta Al: borç alan sensin
      newDebt = DebtModel(
        debtId: null,
        borcluId: currentUserId,
        alacakliId: actualOtherPartyId, // ID kullan
        miktar: amount,
        aciklama: _descriptionController.text,
        islemTarihi: now,
        status: 'pending',
        isShared: true,
        requiresApproval: true,
        visibleTo: [currentUserId, actualOtherPartyId], // ID kullan
        createdBy: currentUserId,
      );
    } else {
      // Pacta Ver: borç veren sensin
      newDebt = DebtModel(
        debtId: null,
        borcluId: actualOtherPartyId, // ID kullan
        alacakliId: currentUserId,
        miktar: amount,
        aciklama: _descriptionController.text,
        islemTarihi: now,
        status: 'pending',
        isShared: true,
        requiresApproval: true,
        visibleTo: [currentUserId, actualOtherPartyId], // ID kullan
        createdBy: currentUserId,
      );
    }
    await _firestoreService.addDebt(newDebt);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Alacak kaydı oluşturuldu!')));
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Size size = MediaQuery.of(context).size;
    final double width = size.width;
    final double height = size.height;
    final cardColor = isDark ? const Color(0xFF23262F) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF111827);
    final textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final green = const Color(0xFF4ADE80);
    final bg = isDark ? const Color(0xFF181A20) : const Color(0xFFF9FAFB);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textMain,
            size: width * 0.07,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Neredeyse Bitti',
          style: TextStyle(
            color: textMain,
            fontWeight: FontWeight.bold,
            fontSize: width * 0.055,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(width * 0.06),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Açıklama',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: width * 0.045,
                    color: textMain,
                  ),
                ),
                SizedBox(height: height * 0.01),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  enabled: true,
                  style: TextStyle(fontSize: width * 0.045, color: textMain),
                  decoration: InputDecoration(
                    hintText: 'Açıklama ekle',
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: green, width: 2),
                    ),
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : textSec,
                      fontSize: width * 0.04,
                    ),
                  ),
                  // validator: (val) => null, // validasyon yok, opsiyonel
                ),
                SizedBox(height: height * 0.025),
                Text(
                  'Tahmini Ödeme Tarihi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: width * 0.045,
                    color: textMain,
                  ),
                ),
                SizedBox(height: height * 0.01),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedDueDate == null
                            ? 'Tarih seçilmedi'
                            : DateFormat(
                                'd MMMM y',
                                'tr_TR',
                              ).format(_selectedDueDate!),
                        style: TextStyle(
                          fontSize: width * 0.04,
                          color: textSec,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.calendar_month_rounded,
                        color: green,
                        size: width * 0.07,
                      ),
                      onPressed: _pickDueDate,
                    ),
                  ],
                ),
                SizedBox(height: height * 0.018),
                Row(
                  children: [
                    Switch(
                      value: _showNote,
                      onChanged: (val) => setState(() => _showNote = val),
                      activeColor: green,
                      inactiveTrackColor: isDark ? Colors.white24 : null,
                    ),
                    Text(
                      'Not Modu',
                      style: TextStyle(
                        color: textMain,
                        fontWeight: FontWeight.w500,
                        fontSize: width * 0.042,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveDebt,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, height * 0.07),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Oluştur',
                      style: TextStyle(
                        fontSize: width * 0.05,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
