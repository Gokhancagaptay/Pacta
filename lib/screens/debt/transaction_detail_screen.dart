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
  String? _localStatus;

  @override
  void initState() {
    super.initState();
    _alacakliName = _firestoreService.getUserNameById(widget.debt.alacakliId);
    _borcluName = _firestoreService.getUserNameById(widget.debt.borcluId);
    _localStatus = widget.debt.status;
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isProcessing) return;

    // Sadece 'pending' durumundaki işlemler için statü değişikliğine izin ver
    if (widget.debt.status == 'pending') {
      setState(() => _isProcessing = true);

      try {
        await _firestoreService.updateDebtStatus(
          widget.debt.debtId!,
          newStatus,
        );

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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sadece beklemedeki işlemlerin durumu değiştirilebilir.',
          ),
        ),
      );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Size size = MediaQuery.of(context).size;
    final double width = size.width;
    final double height = size.height;
    final green = const Color(0xFF4ADE80);
    final red = const Color(0xFFF87171);
    final bgColor = isDark ? const Color(0xFF181A20) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF23262F) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF111827);
    final textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final isAlacakli = widget.debt.alacakliId == widget.userId;
    final amountColor = isAlacakli ? green : red;
    final amountPrefix = isAlacakli ? '+' : '-';
    final String? aciklama = widget.debt.aciklama;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final createdBy = widget.debt.toMap()['createdBy'] ?? '';
    final isCreator = createdBy.isNotEmpty
        ? (createdBy == currentUserId)
        : (widget.debt.alacakliId == currentUserId ||
              widget.debt.borcluId == currentUserId);
    final isOnaylayici =
        !isCreator &&
        (currentUserId == widget.debt.alacakliId ||
            currentUserId == widget.debt.borcluId);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('İşlemi Sil'),
                    content: const Text(
                      'Bu işlemi kalıcı olarak silmek istediğinize emin misiniz?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('İptal'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Sil',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  // Firestore'dan silme işlemini çağır ve sonra geri git
                  await _firestoreService.deleteDebt(widget.debt.debtId!);
                  Navigator.pop(context);
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    'İşlemi Sil',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<DebtModel?>(
        stream: _firestoreService.getDebtByIdStream(widget.debt.debtId!),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final debt = snapshot.data!;
          final status = debt.status;
          final requiresApproval = debt.requiresApproval;
          final isNote = debt.status == 'note';
          final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
          final createdBy = debt.toMap()['createdBy'] ?? '';
          final isCreator = createdBy.isNotEmpty
              ? (createdBy == currentUserId)
              : (debt.alacakliId == currentUserId ||
                    debt.borcluId == currentUserId);
          final isOnaylayici =
              !isCreator &&
              (currentUserId == debt.alacakliId ||
                  currentUserId == debt.borcluId);
          final showActionButtons =
              status == 'pending' &&
              requiresApproval &&
              isOnaylayici &&
              !isNote;
          final showStatusLabel =
              status == 'approved' ||
              status == 'rejected' ||
              (status == 'pending' && isCreator);
          // Karşı tarafın adının baş harfi için
          final isAlacakli = debt.alacakliId == widget.userId;
          final otherPartyId = isAlacakli ? debt.borcluId : debt.alacakliId;
          return Column(
            children: [
              // Üst header
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: height * 0.07,
                  bottom: height * 0.09,
                ),
                decoration: BoxDecoration(
                  color: amountColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: amountColor.withOpacity(0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FutureBuilder<String>(
                        future: _firestoreService.getUserNameById(otherPartyId),
                        builder: (context, snap) {
                          String initial = '?';
                          if (snap.connectionState == ConnectionState.done &&
                              snap.data != null &&
                              snap.data!.isNotEmpty) {
                            initial = snap.data!.trim()[0].toUpperCase();
                          }
                          return CircleAvatar(
                            radius: width * 0.13,
                            backgroundColor: Colors.white,
                            child: Text(
                              initial,
                              style: GoogleFonts.poppins(
                                color: amountColor,
                                fontWeight: FontWeight.bold,
                                fontSize: width * 0.09,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: height * 0.02),
                    Text(
                      '$amountPrefix${debt.miktar.toStringAsFixed(2)}₺',
                      style: GoogleFonts.poppins(
                        fontSize: width * 0.13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: height * 0.01),
                    FutureBuilder<String>(
                      future: isAlacakli ? _borcluName : _alacakliName,
                      builder: (context, snapshot) {
                        final name =
                            snapshot.connectionState == ConnectionState.done
                            ? (snapshot.data ?? '-')
                            : '-';
                        return Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.normal,
                            fontSize: width * 0.05,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Alt detaylar ve butonlar
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: height * 0.01,
                    bottom: height * 0.03,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      color: cardColor,
                      elevation: isDark ? 2 : 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(
                          color: isDark ? Colors.white10 : Colors.grey[200]!,
                          width: 1.2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 20.0,
                        ),
                        child: Column(
                          children: [
                            // Table yerine modern ve kutu/kart görünümlü satırlar:
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Column(
                                children: [
                                  _modernRow(
                                    Icons.attach_money,
                                    'Tutar',
                                    '${debt.miktar.toStringAsFixed(2)}₺',
                                    textMain,
                                  ),
                                  const SizedBox(height: 12),
                                  _modernRow(
                                    Icons.calendar_today,
                                    'Tarih',
                                    DateFormat(
                                      'd MMM y, HH:mm',
                                      'tr_TR',
                                    ).format(debt.islemTarihi),
                                    textMain,
                                  ),
                                  const SizedBox(height: 12),
                                  _modernRow(
                                    Icons.confirmation_number,
                                    'Transaction ID',
                                    debt.debtId ?? '-',
                                    textMain,
                                    copyable: true,
                                  ),
                                  if (!isNote) ...[
                                    const SizedBox(height: 12),
                                    FutureBuilder<String>(
                                      future: _alacakliName,
                                      builder: (context, snapshot) =>
                                          _modernRow(
                                            Icons.person,
                                            'Alacaklı',
                                            snapshot.connectionState ==
                                                    ConnectionState.done
                                                ? (snapshot.data ?? '-')
                                                : '-',
                                            textMain,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    FutureBuilder<String>(
                                      future: _borcluName,
                                      builder: (context, snapshot) =>
                                          _modernRow(
                                            Icons.person_outline,
                                            'Borçlu',
                                            snapshot.connectionState ==
                                                    ConnectionState.done
                                                ? (snapshot.data ?? '-')
                                                : '-',
                                            textMain,
                                          ),
                                    ),
                                  ],
                                  if (debt.aciklama != null &&
                                      debt.aciklama!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    _modernRow(
                                      Icons.note,
                                      'Açıklama',
                                      debt.aciklama!,
                                      textMain,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Butonlar Table'ın dışında, en altta
                            if (showActionButtons)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 16.0,
                                  left: 0.0,
                                  right: 0.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 52,
                                        child: OutlinedButton(
                                          onPressed: _isProcessing
                                              ? null
                                              : () => _updateStatus('rejected'),
                                          child: const Text('Reddet'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: red,
                                            side: BorderSide(color: red),
                                            textStyle: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            backgroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: SizedBox(
                                        height: 52,
                                        child: ElevatedButton(
                                          onPressed: _isProcessing
                                              ? null
                                              : () => _updateStatus('approved'),
                                          child: const Text('Onayla'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: green,
                                            textStyle: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            elevation: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (showStatusLabel)
                              _statusButton(
                                status == 'pending'
                                    ? 'Beklemede'
                                    : status == 'approved'
                                    ? 'Onaylandı'
                                    : 'Reddedildi',
                                status == 'approved'
                                    ? green
                                    : status == 'rejected'
                                    ? red
                                    : Colors.grey,
                                width,
                              ),
                            if (_isProcessing)
                              const Padding(
                                padding: EdgeInsets.only(top: 16.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getInitials() {
    final isAlacakli = widget.debt.alacakliId == widget.userId;
    String id = isAlacakli ? widget.debt.borcluId : widget.debt.alacakliId;
    if (id.isNotEmpty) {
      return id.substring(0, id.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '?';
  }

  Widget _detailRow(
    String label,
    String value,
    Color textMain,
    Color textSec,
    double width,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.normal,
              fontSize: width * 0.038,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                color: textMain,
                fontWeight: FontWeight.w600,
                fontSize: width * 0.041,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRowWithCopy(
    String label,
    String value,
    Color textMain,
    Color textSec,
    double width,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.normal,
              fontSize: width * 0.038,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                color: textMain,
                fontWeight: FontWeight.w600,
                fontSize: width * 0.041,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, size: width * 0.055, color: textSec),
            onPressed: () => _copyToClipboard(value),
            tooltip: 'Kopyala',
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback? onTap,
    required double width,
    required bool filled,
  }) {
    final isRed = color == const Color(0xFFF87171);
    return SizedBox(
      height: 58,
      child: filled
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                elevation: 4,
                minimumSize: const Size.fromHeight(58),
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 8,
                ),
                textStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: width * 0.048,
                  letterSpacing: 0.2,
                ),
                shadowColor: color.withOpacity(0.25),
              ),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: width * 0.048,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                minimumSize: const Size.fromHeight(58),
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 8,
                ),
                textStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: width * 0.048,
                  letterSpacing: 0.2,
                ),
                backgroundColor: Colors.white,
              ),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: width * 0.048,
                    color: color,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _statusButton(String label, Color color, double width) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: color.withOpacity(0.13),
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: width * 0.045,
        ),
      ),
    );
  }

  // Hata: '_detailRow' fonksiyonu zaten tanımlı. Fonksiyon adını değiştiriyoruz.
  Widget _transactionDetailRow(
    IconData? icon,
    String label,
    String value,
    Color textMain, {
    bool copyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: Colors.grey[400]),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (copyable)
                  IconButton(
                    icon: Icon(Icons.copy, size: 18, color: Colors.grey[400]),
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

  Widget _detailsSection(
    double width,
    double height,
    Color textMain,
    Color textSec,
    String? aciklama,
    bool isNote,
    Future<String> _alacakliName,
    Future<String> _borcluName,
  ) {
    final List<Map<String, dynamic>> rows = [
      {'label': 'Tutar', 'value': '${widget.debt.miktar.toStringAsFixed(2)}₺'},
      {
        'label': 'Tarih',
        'value': DateFormat(
          'd MMM y, HH:mm',
          'tr_TR',
        ).format(widget.debt.islemTarihi),
      },
      {
        'label': 'Transaction ID',
        'value': widget.debt.debtId ?? '-',
        'copy': true,
      },
    ];
    if (!isNote) {
      rows.add({'label': 'Alacaklı', 'future': _alacakliName});
      rows.add({'label': 'Borçlu', 'future': _borcluName});
    }
    if (aciklama != null && aciklama.isNotEmpty) {
      rows.add({'label': 'Açıklama', 'value': aciklama});
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0.01),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sol başlıklar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    child: Text(
                      row['label'],
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.normal,
                        fontSize: width * 0.038,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(width: 18),
          // Sağ değerler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: rows.map((row) {
                if (row['future'] != null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    child: FutureBuilder<String>(
                      future: row['future'],
                      builder: (context, snapshot) => Text(
                        snapshot.connectionState == ConnectionState.done
                            ? (snapshot.data ?? '-')
                            : '-',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.poppins(
                          color: textMain,
                          fontWeight: FontWeight.w600,
                          fontSize: width * 0.041,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                } else if (row['copy'] == true) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            row['value'],
                            textAlign: TextAlign.right,
                            style: GoogleFonts.poppins(
                              color: textMain,
                              fontWeight: FontWeight.w600,
                              fontSize: width * 0.041,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.copy,
                            size: width * 0.055,
                            color: textSec,
                          ),
                          onPressed: () => _copyToClipboard(row['value']),
                          tooltip: 'Kopyala',
                        ),
                      ],
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    child: Text(
                      row['value'],
                      textAlign: TextAlign.right,
                      style: GoogleFonts.poppins(
                        color: textMain,
                        fontWeight: FontWeight.w600,
                        fontSize: width * 0.041,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Table yardımcı fonksiyonları:
  TableRow _tableRow(
    IconData? icon,
    String label,
    String value,
    Color textMain, {
    bool copyable = false,
  }) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: _tableLabel(icon, label),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: _tableValue(value, textMain, copyable: copyable),
          ),
        ),
      ],
    );
  }

  TableRow _tableSpacer() =>
      TableRow(children: [SizedBox(height: 20), SizedBox(height: 20)]);
  Widget _tableLabel(IconData? icon, String label) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: Colors.grey[400]),
          const SizedBox(width: 8),
        ],
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
      ],
    );
  }

  Widget _tableValue(String value, Color textMain, {bool copyable = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.right,
          ),
        ),
        if (copyable)
          IconButton(
            icon: Icon(Icons.copy, size: 20, color: Colors.grey[400]),
            onPressed: () => _copyToClipboard(value),
            tooltip: 'Kopyala',
          ),
      ],
    );
  }

  // Modern satır fonksiyonu:
  Widget _modernRow(
    IconData? icon,
    String label,
    String value,
    Color textMain, {
    bool copyable = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color rowBg = isDark ? const Color(0xFF23262F) : Colors.grey[50]!;
    final Color borderColor = isDark ? Colors.white10 : Colors.grey[200]!;
    final Color iconColor = isDark ? Colors.white38 : Colors.grey[400]!;
    final Color labelColor = isDark ? Colors.white70 : Colors.grey[600]!;
    final Size size = MediaQuery.of(context).size;
    final double width = size.width;
    return Container(
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.10)
                : Colors.grey.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.03,
        vertical: width * 0.045,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: width * 0.06, color: iconColor),
                SizedBox(width: width * 0.025),
              ],
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: width * 0.042,
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
                      fontSize: width * 0.048,
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
                      size: width * 0.055,
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
