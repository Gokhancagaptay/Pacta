import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pacta/models/debt_model.dart';
import 'package:pacta/screens/debt/transaction_detail_screen.dart';
import 'package:pacta/services/firestore_service.dart';

class AllTransactionsScreen extends StatelessWidget {
  final String title;
  final String userId;
  final List<String> statuses;

  const AllTransactionsScreen({
    super.key,
    required this.title,
    required this.userId,
    required this.statuses,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF181A20) : const Color(0xFFF9FAFB);
    final Color textMain = isDark ? Colors.white : const Color(0xFF111827);
    final Color textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: textMain)),
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textMain),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: StreamBuilder<List<DebtModel>>(
            stream: firestoreService.getUserDebtsStream(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Bir hata oluştu: ${snapshot.error}',
                    style: TextStyle(color: textSec),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState(context, textSec);
              }

              final allDebts = snapshot.data!;
              final filteredDebts = allDebts
                  .where((d) => statuses.contains(d.status))
                  .toList();

              if (filteredDebts.isEmpty) {
                return _buildEmptyState(context, textSec);
              }

              filteredDebts.sort(
                (a, b) => b.islemTarihi.compareTo(a.islemTarihi),
              );

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                itemCount: filteredDebts.length,
                itemBuilder: (context, index) {
                  final debt = filteredDebts[index];
                  return _TransactionCard(d: debt, userId: userId);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color textSec) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_off_outlined,
            size: 60,
            color: textSec.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Burada gösterilecek bir şey yok.',
            style: TextStyle(fontSize: 16, color: textSec),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final DebtModel d;
  final String userId;

  const _TransactionCard({required this.d, required this.userId});

  String getStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Onaylandı';
      case 'pending':
        return 'Bekleniyor';
      case 'rejected':
        return 'Reddedildi';
      case 'note':
        return 'Not';
      default:
        return '-';
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF4ADE80);
      case 'pending':
        return const Color(0xFFFFA726);
      case 'rejected':
        return const Color(0xFFF87171);
      case 'note':
        return const Color(0xFF6B7280);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textMain = isDark ? Colors.white : const Color(0xFF111827);
    final Color textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    const Color green = Color(0xFF4ADE80);
    const Color red = Color(0xFFF87171);

    final bool isAlacak = d.alacakliId == userId;
    final bool isNote = d.status == 'note';
    final Color amountColor = isNote ? green : (isAlacak ? green : red);
    final String amountPrefix = isNote ? '+' : (isAlacak ? '+' : '-');
    final String otherPartyId = isAlacak ? d.borcluId : d.alacakliId;
    final String statusLabel = getStatusLabel(d.status);
    final Color statusColor = getStatusColor(d.status);
    final firestoreService = FirestoreService();

    return FutureBuilder<String>(
      future: firestoreService.getUserNameById(otherPartyId),
      builder: (context, snapshot) {
        final otherPartyName = snapshot.connectionState == ConnectionState.done
            ? (snapshot.data ?? otherPartyId.substring(0, 6))
            : '...';
        final Color cardBg = isDark ? const Color(0xFF23262F) : Colors.white;
        final Color borderColor = isDark ? Colors.white10 : Colors.grey[200]!;

        return LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = constraints.maxWidth;
            final double avatarRadius = cardWidth * 0.08;
            final double horizontalPadding = cardWidth * 0.04;
            final double verticalPadding = cardWidth * 0.03;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TransactionDetailScreen(debt: d, userId: userId),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                padding: EdgeInsets.symmetric(
                  vertical: verticalPadding,
                  horizontal: horizontalPadding,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: amountColor.withOpacity(isDark ? 0.10 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: amountColor.withOpacity(0.13),
                      child: Text(
                        (otherPartyName.isNotEmpty
                            ? otherPartyName[0].toUpperCase()
                            : '?'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: avatarRadius,
                          color: amountColor,
                        ),
                      ),
                    ),
                    SizedBox(width: horizontalPadding),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            otherPartyName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: cardWidth * 0.045,
                              color: textMain,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            d.aciklama?.isNotEmpty == true
                                ? d.aciklama!
                                : 'Açıklama bulunamadı 🤔',
                            style: TextStyle(
                              fontSize: cardWidth * 0.038,
                              color: textSec,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4.0),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: [
                              Text(
                                d.islemTarihi != null
                                    ? DateFormat(
                                        'd MMMM y',
                                        'tr_TR',
                                      ).format(d.islemTarihi)
                                    : '-',
                                style: TextStyle(
                                  fontSize: cardWidth * 0.032,
                                  color: textSec,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.13),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: cardWidth * 0.032,
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      amountPrefix + d.miktar.toStringAsFixed(2) + '₺',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: cardWidth * 0.042,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
