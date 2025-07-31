// lib/screens/debt/add_debt_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pacta/models/debt_model.dart';
import 'package:pacta/models/user_model.dart';
import 'package:pacta/services/firestore_service.dart';

import 'package:pacta/models/saved_contact_model.dart';
// ... (existing imports)

class AddDebtScreen extends ConsumerStatefulWidget {
  final String? amount;
  final SavedContactModel selectedContact;
  final bool isPactaAl;
  final bool isNote;

  const AddDebtScreen({
    Key? key,
    this.amount,
    required this.selectedContact,
    this.isPactaAl = false,
    this.isNote = false,
  }) : super(key: key);

  @override
  ConsumerState<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends ConsumerState<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _personController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  bool _isPacta = true; // Default to true

  @override
  void initState() {
    super.initState();
    if (widget.amount != null) {
      _amountController.text = widget.amount!;
    }
    _personController.text = widget.selectedContact.email;

    // If it's a note-only contact, force _isPacta to false.
    // Otherwise, respect the isNote flag from the dashboard.
    if (widget.selectedContact.uid == null) {
      _isPacta = false;
    } else {
      _isPacta = !widget.isNote;
    }
  }
  // ... (rest of the file)

  @override
  void dispose() {
    _amountController.dispose();
    _personController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveDebt() async {
    if (_isSaving) return;

    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      try {
        final miktar = double.tryParse(_amountController.text);
        if (miktar == null || miktar <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lütfen geçerli bir tutar girin.')),
          );
          if (mounted) setState(() => _isSaving = false);
          return;
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          if (mounted) setState(() => _isSaving = false);
          return;
        }

        final firestoreService = FirestoreService();
        UserModel? otherUser;

        if (widget.selectedContact.uid != null) {
          otherUser = await firestoreService.getUserByEmail(
            _personController.text,
          );
        } else {
          // This is a note-only contact, create a temporary UserModel
          otherUser = UserModel(
            uid:
                widget.selectedContact.id ??
                'note_user_${DateTime.now().millisecondsSinceEpoch}',
            email: widget.selectedContact.email,
            adSoyad: widget.selectedContact.adSoyad,
          );
        }

        if (otherUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu e-posta adresine sahip bir kullanıcı yok.'),
            ),
          );
          if (mounted) setState(() => _isSaving = false);
          return;
        }

        final borcluId = widget.isPactaAl ? currentUser.uid : otherUser.uid;
        final alacakliId = widget.isPactaAl ? otherUser.uid : currentUser.uid;

        final newDebt = DebtModel(
          borcluId: borcluId,
          alacakliId: alacakliId,
          miktar: miktar,
          aciklama: _descriptionController.text,
          islemTarihi: _selectedDate,
          status: _isPacta ? 'pending' : 'note',
          isShared: _isPacta,
          requiresApproval: _isPacta,
          visibleto: [currentUser.uid, otherUser.uid],
          createdBy: currentUser.uid,
        );

        final newDebtId = await firestoreService.addDebt(newDebt);

        if (_isPacta) {
          await firestoreService.sendNotification(
            toUserId: otherUser.uid,
            createdById: currentUser.uid,
            type: 'approval_request',
            relatedDebtId: newDebtId,
            title: widget.isPactaAl ? 'Alacak Talebi' : 'Borç Talebi',
            message:
                '${currentUser.displayName ?? currentUser.email} sizden ${newDebt.miktar.toStringAsFixed(2)}₺ tutarında bir talepte bulundu.',
            debtorId: newDebt.borcluId,
            creditorId: newDebt.alacakliId,
            amount: newDebt.miktar,
          );
        }

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Bir hata oluştu: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.isNote ? 'Not Ekle' : 'Pacta Oluştur',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: theme.colorScheme.onBackground),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildAmountCard(theme),
            const SizedBox(height: 16),
            _buildInputCard(
              icon: Icons.person_outline,
              child: TextFormField(
                controller: _personController,
                decoration: const InputDecoration(
                  hintText: 'Kişi (E-posta)',
                  border: InputBorder.none,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Lütfen bir kişi girin';
                  if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value))
                    return 'Lütfen geçerli bir e-posta adresi girin.';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildInputCard(
              icon: Icons.edit_outlined,
              child: TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  hintText: 'Açıklama (Örn: Öğle yemeği)',
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(height: 16),
            _buildInputCard(
              icon: Icons.calendar_today_outlined,
              isTappable: true,
              onTap: () => _selectDate(context),
              child: Text(
                DateFormat('d MMMM y, EEEE', 'tr_TR').format(_selectedDate),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            if (!widget.isNote) _buildPactaSwitchCard(theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomButton(theme),
    );
  }

  Widget _buildAmountCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final color = widget.isPactaAl ? Colors.green : Colors.red;

    return Card(
      elevation: 4.0,
      shadowColor: color.withOpacity(isDark ? 0.3 : 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: isDark ? color.withOpacity(0.2) : color.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _amountController,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48.0,
                  fontWeight: FontWeight.bold,
                  color: isDark ? color.shade200 : color.shade800,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 48.0,
                    fontWeight: FontWeight.bold,
                    color: theme.hintColor.withOpacity(0.5),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null ||
                      value.isEmpty ||
                      double.tryParse(value)! <= 0)
                    return 'Tutar girmelisiniz';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₺',
              style: TextStyle(
                fontSize: 28.0,
                fontWeight: FontWeight.normal,
                color: isDark ? color.shade200 : color.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required IconData icon,
    required Widget child,
    bool isTappable = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2.0,
      shadowColor: theme.shadowColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: theme.cardColor,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: isTappable ? onTap : null,
        borderRadius: BorderRadius.circular(12.0),
        child: ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: child,
        ),
      ),
    );
  }

  Widget _buildPactaSwitchCard(ThemeData theme) {
    // A note-only contact cannot be part of a Pacta (approval-based debt)
    final bool isNoteOnlyContact = widget.selectedContact.uid == null;

    return Card(
      elevation: 2.0,
      shadowColor: theme.shadowColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: theme.cardColor,
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        title: const Text(
          'Onay Gereksin (Pacta)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          isNoteOnlyContact
              ? 'Bu kişiyle sadece not oluşturabilirsiniz.'
              : 'Bu işlem karşı tarafın onayına sunulacaktır.',
          style: theme.textTheme.bodySmall,
        ),
        value: _isPacta,
        onChanged: isNoteOnlyContact
            ? null // Disable the switch if it's a note-only contact
            : (bool value) => setState(() => _isPacta = value),
        activeColor: theme.colorScheme.primary,
        secondary: Icon(
          Icons.shield_outlined,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildBottomButton(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveDebt,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          minimumSize: const Size(double.infinity, 56),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        child: _isSaving
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.onPrimary,
                ),
              )
            : const Text('Pacta Gönder'),
      ),
    );
  }
}
