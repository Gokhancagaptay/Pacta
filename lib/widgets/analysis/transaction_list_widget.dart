// lib/widgets/analysis/transaction_list_widget.dart

import 'package:flutter/material.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:pacta/utils/format_utils.dart';
import 'package:pacta/models/debt_model.dart';
import 'package:pacta/screens/debt/transaction_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// İşlem listesi widget'ı
class TransactionListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final bool isLoading;

  const TransactionListWidget({
    super.key,
    required this.transactions,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppConstants.defaultPadding),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (transactions.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: transactions.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppConstants.smallPadding),
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _TransactionCard(transaction: transaction);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: AppSizes.iconExtraLarge,
                color: Theme.of(context).primaryColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              'İşlem bulunamadı',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              'Seçilen kriterlere uygun işlem bulunmuyor.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tekil işlem kartı
class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isDebt = transaction['borcluId'] == currentUserId;
    final amount = (transaction['miktar'] as num?)?.toDouble() ?? 0;
    final status = transaction['status']?.toString() ?? '';
    final date = transaction['tarih'] as DateTime?;
    final description = transaction['aciklama']?.toString() ?? '';

    return Card(
      elevation: AppSizes.cardElevation,
      child: InkWell(
        onTap: () => _showTransactionDetail(context),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            children: [
              Row(
                children: [
                  // İşlem türü ikonu
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTransactionIcon(isDebt, status),
                      color: _getStatusColor(status),
                      size: AppSizes.iconMedium,
                    ),
                  ),

                  const SizedBox(width: AppConstants.defaultPadding),

                  // İşlem detayları
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _getTransactionTitle(isDebt, status),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                FormatUtils.formatStatus(status),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: _getStatusColor(status),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),

                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withOpacity(0.7),
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.defaultPadding),

              // Alt bilgiler
              Row(
                children: [
                  if (date != null) ...[
                    Icon(
                      Icons.schedule,
                      size: AppSizes.iconSmall,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      FormatUtils.formatDate(date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Tutar
                  Text(
                    '${isDebt ? '-' : '+'}${FormatUtils.formatCurrency(amount)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDebt ? AppColors.debt : AppColors.credit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionDetail(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      final debt = DebtModel.fromMap({
        ...transaction,
        'islemTarihi': transaction['tarih'] != null
            ? Timestamp.fromDate(transaction['tarih'] as DateTime)
            : Timestamp.now(),
      }, transaction['debtId'] ?? '');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TransactionDetailScreen(debt: debt, userId: currentUserId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İşlem detayı açılırken hata oluştu: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  IconData _getTransactionIcon(bool isDebt, String status) {
    if (status == AppConstants.statusNote) {
      return Icons.note_alt;
    }
    return isDebt ? Icons.arrow_upward : Icons.arrow_downward;
  }

  String _getTransactionTitle(bool isDebt, String status) {
    if (status == AppConstants.statusNote) {
      return isDebt ? 'Not Borcum' : 'Not Alacağım';
    }
    return isDebt ? 'Borcum' : 'Alacağım';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.approved;
      case 'note':
        return AppColors.pending;
      case 'pending':
        return AppColors.warning;
      case 'rejected':
        return AppColors.rejected;
      default:
        return Colors.grey;
    }
  }
}
