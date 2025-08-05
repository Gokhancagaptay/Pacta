import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pacta/models/debt_model.dart';
import 'package:pacta/services/firestore_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionDetailScreen extends StatefulWidget {
  final DebtModel debt;
  final String userId;
  const TransactionDetailScreen({
    Key? key,
    required this.debt,
    required this.userId,
  }) : super(key: key);

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late Future<String> _alacakliName;
  late Future<String> _borcluName;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _alacakliName = _firestoreService.getUserNameById(widget.debt.alacakliId);
    _borcluName = _firestoreService.getUserNameById(widget.debt.borcluId);
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _firestoreService.updateDebtStatus(widget.debt.debtId!, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'approved'
                  ? 'İşlem onaylandı.'
                  : 'İşlem reddedildi.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata oluştu: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _deleteDebt() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _firestoreService.deleteDebt(widget.debt.debtId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşlem başarıyla silindi.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silinirken bir hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _respondToDeleteRequest(bool approved) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _firestoreService.respondToDeleteRequest(
        widget.debt.debtId!,
        approved,
        FirebaseAuth.instance.currentUser!.uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approved ? 'Silme talebi onaylandı.' : 'Silme talebi reddedildi.',
            ),
          ),
        );
        if (approved && mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Bir hata oluştu: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Kopyalandı!')));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return StreamBuilder<DebtModel?>(
      stream: _firestoreService.getDebtByIdStream(widget.debt.debtId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(body: Container());
        }

        final debt = snapshot.data!;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final green = const Color(0xFF4ADE80);
        final red = const Color(0xFFF87171);
        final bgColor = isDark
            ? const Color(0xFF181A20)
            : const Color(0xFFF5F5F5);
        final cardColor = isDark ? const Color(0xFF23262F) : Colors.white;
        final textMain = isDark ? Colors.white : const Color(0xFF111827);
        final isAlacakli = debt.alacakliId == widget.userId;
        final amountColor = isAlacakli ? green : red;
        final amountPrefix = isAlacakli ? '+' : '-';
        final status = debt.status;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
        final isCreator = (debt.createdBy?.isNotEmpty ?? false)
            ? (debt.createdBy == currentUserId)
            : (debt.borcluId == currentUserId);
        final isOnaylayici =
            !isCreator &&
            (currentUserId == debt.alacakliId ||
                currentUserId == debt.borcluId);
        final showPendingApprovalButtons =
            status == 'pending' &&
            debt.requiresApproval &&
            isOnaylayici &&
            debt.status != 'note';
        final showDeletionApprovalButtons =
            status == 'pending_deletion' &&
            debt.deletionRequesterId != currentUserId;
        final showStatusLabel =
            status == 'approved' ||
            status == 'rejected' ||
            status == 'pending_deletion' ||
            (status == 'pending' && isCreator);
        final otherPartyId = isAlacakli ? debt.borcluId : debt.alacakliId;

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('İşlemi Sil'),
                        content: const Text(
                          'Bu işlemi kalıcı olarak silmek istediğinizden emin misiniz?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('İptal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Sil'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _deleteDebt();
                    }
                  } else if (value == 'request_deletion') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Silme Talebi Gönder'),
                        content: const Text(
                          'Bu işlemi silmek için diğer tarafa bir onay talebi gönderilecek. Emin misiniz?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('İptal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Gönder'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _firestoreService.requestDebtDeletion(
                        debt.debtId!,
                        currentUserId,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Silme talebi gönderildi.'),
                          ),
                        );
                      }
                    }
                  }
                },
                itemBuilder: (BuildContext context) {
                  List<PopupMenuEntry<String>> items = [];
                  if (debt.status == 'approved') {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'request_deletion',
                        child: ListTile(
                          leading: Icon(Icons.send_to_mobile),
                          title: Text('Silme Talebi Gönder'),
                        ),
                      ),
                    );
                  } else if (debt.status == 'note' ||
                      debt.status == 'rejected') {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                          title: Text(
                            'Sil',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    );
                  }
                  return items;
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: size.height * 0.07,
                  bottom: size.height * 0.09,
                ),
                decoration: BoxDecoration(
                  color: amountColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(size.width * 0.08),
                    bottomRight: Radius.circular(size.width * 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    FutureBuilder<String>(
                      future: _firestoreService.getUserNameById(otherPartyId),
                      builder: (context, snap) {
                        String initial = '?';
                        if (snap.connectionState == ConnectionState.done &&
                            snap.hasData &&
                            snap.data!.isNotEmpty) {
                          initial = snap.data!.trim()[0].toUpperCase();
                        }
                        return CircleAvatar(
                          radius: size.width * 0.13,
                          backgroundColor: Colors.white,
                          child: Text(
                            initial,
                            style: GoogleFonts.poppins(
                              color: amountColor,
                              fontWeight: FontWeight.bold,
                              fontSize: size.width * 0.09,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: size.height * 0.02),
                    Text(
                      '$amountPrefix${debt.miktar.toStringAsFixed(2)}₺',
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: size.height * 0.01),
                    FutureBuilder<String>(
                      future: isAlacakli ? _borcluName : _alacakliName,
                      builder: (context, snapshot) {
                        final name = snapshot.data ?? '...';
                        return Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: size.width * 0.05,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    vertical: size.height * 0.01,
                    horizontal: size.width * 0.04,
                  ),
                  child: Card(
                    color: cardColor,
                    elevation: isDark ? 2 : 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(size.width * 0.07),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: size.width * 0.04,
                        vertical: size.height * 0.025,
                      ),
                      child: Column(
                        children: [
                          _modernRow(
                            context,
                            Icons.attach_money,
                            'Tutar',
                            '${debt.miktar.toStringAsFixed(2)}₺',
                            textMain,
                          ),
                          SizedBox(height: size.height * 0.015),
                          _modernRow(
                            context,
                            Icons.calendar_today,
                            'Tarih',
                            DateFormat(
                              'd MMM y, HH:mm',
                              'tr_TR',
                            ).format(debt.islemTarihi),
                            textMain,
                          ),
                          SizedBox(height: size.height * 0.015),
                          _modernRow(
                            context,
                            Icons.confirmation_number,
                            'Transaction ID',
                            debt.debtId ?? '-',
                            textMain,
                            copyable: true,
                          ),
                          if (debt.status != 'note') ...[
                            SizedBox(height: size.height * 0.015),
                            FutureBuilder<String>(
                              future: _alacakliName,
                              builder: (context, snapshot) => _modernRow(
                                context,
                                Icons.person,
                                'Alacaklı',
                                snapshot.data ?? '-',
                                textMain,
                              ),
                            ),
                            SizedBox(height: size.height * 0.015),
                            FutureBuilder<String>(
                              future: _borcluName,
                              builder: (context, snapshot) => _modernRow(
                                context,
                                Icons.person_outline,
                                'Borçlu',
                                snapshot.data ?? '-',
                                textMain,
                              ),
                            ),
                          ],
                          if (debt.aciklama?.isNotEmpty ?? false) ...[
                            SizedBox(height: size.height * 0.015),
                            _modernRow(
                              context,
                              Icons.note,
                              'Açıklama',
                              debt.aciklama!,
                              textMain,
                            ),
                          ],
                          SizedBox(height: size.height * 0.025),
                          if (showPendingApprovalButtons)
                            _buildActionButtons(
                              context,
                              onReject: () => _updateStatus('rejected'),
                              onApprove: () => _updateStatus('approved'),
                              rejectText: 'Reddet',
                              approveText: 'Onayla',
                            ),
                          if (showDeletionApprovalButtons)
                            _buildActionButtons(
                              context,
                              onReject: () => _respondToDeleteRequest(false),
                              onApprove: () => _respondToDeleteRequest(true),
                              rejectText: 'Talebi Reddet',
                              approveText: 'Silmeyi Onayla',
                            ),
                          if (showStatusLabel)
                            _statusButton(
                              context,
                              status == 'pending'
                                  ? 'Onay Bekliyor'
                                  : status == 'approved'
                                  ? 'Onaylandı'
                                  : status == 'pending_deletion'
                                  ? 'Silme Talebi Gönderildi'
                                  : 'Reddedildi',
                              status == 'approved'
                                  ? green
                                  : status == 'rejected'
                                  ? red
                                  : status == 'pending_deletion'
                                  ? Colors.orange
                                  : Colors.grey,
                            ),
                          if (_isProcessing)
                            Padding(
                              padding: EdgeInsets.only(top: size.height * 0.02),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(
    BuildContext context, {
    required VoidCallback onReject,
    required VoidCallback onApprove,
    required String rejectText,
    required String approveText,
  }) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: EdgeInsets.only(bottom: size.height * 0.02),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: size.height * 0.065,
              child: OutlinedButton(
                onPressed: _isProcessing ? null : onReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(size.width * 0.04),
                  ),
                ),
                child: Text(rejectText),
              ),
            ),
          ),
          SizedBox(width: size.width * 0.05),
          Expanded(
            child: SizedBox(
              height: size.height * 0.065,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : onApprove,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(size.width * 0.04),
                  ),
                ),
                child: Text(approveText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusButton(BuildContext context, String label, Color color) {
    final size = MediaQuery.of(context).size;
    return Container(
      margin: EdgeInsets.only(top: size.height * 0.025),
      width: double.infinity,
      height: size.height * 0.065,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size.width * 0.06),
        color: color.withOpacity(0.13),
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: size.width * 0.045,
        ),
      ),
    );
  }

  Widget _modernRow(
    BuildContext context,
    IconData? icon,
    String label,
    String value,
    Color textMain, {
    bool copyable = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final rowBg = isDark ? const Color(0xFF23262F) : Colors.grey[50]!;
    final borderColor = isDark ? Colors.white10 : Colors.grey[200]!;
    final iconColor = isDark ? Colors.white38 : Colors.grey[400]!;
    final labelColor = isDark ? Colors.white70 : Colors.grey[600]!;

    return Container(
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(size.width * 0.035),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.03,
        vertical: size.height * 0.018,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: size.width * 0.06, color: iconColor),
                SizedBox(width: size.width * 0.025),
              ],
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: size.width * 0.042,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: size.width * 0.048,
                      color: textMain,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.right,
                  ),
                ),
                if (copyable)
                  IconButton(
                    icon: Icon(
                      Icons.copy,
                      size: size.width * 0.055,
                      color: iconColor,
                    ),
                    onPressed: () => _copyToClipboard(value),
                    tooltip: 'Kopyala',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
