// lib/widgets/analysis/summary_cards_widget.dart

import 'package:flutter/material.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:pacta/utils/format_utils.dart';

/// Özet kartları widget'ı
class SummaryCardsWidget extends StatelessWidget {
  final double borclarim;
  final double alacaklarim;
  final double notBorclarim;
  final double notAlacaklarim;
  final String contactName;

  const SummaryCardsWidget({
    super.key,
    required this.borclarim,
    required this.alacaklarim,
    required this.notBorclarim,
    required this.notAlacaklarim,
    required this.contactName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Borçlarım',
                amount: borclarim,
                color: AppColors.debt,
                icon: Icons.arrow_upward,
                subtitle: '$contactName\'e borcum',
              ),
            ),
            const SizedBox(width: AppConstants.smallPadding),
            Expanded(
              child: _SummaryCard(
                title: 'Alacaklarım',
                amount: alacaklarim,
                color: AppColors.credit,
                icon: Icons.arrow_downward,
                subtitle: '$contactName\'den alacağım',
              ),
            ),
          ],
        ),
        if (notBorclarim > 0 || notAlacaklarim > 0) ...[
          const SizedBox(height: AppConstants.smallPadding),
          Row(
            children: [
              if (notBorclarim > 0)
                Expanded(
                  child: _SummaryCard(
                    title: 'Not Borçlarım',
                    amount: notBorclarim,
                    color: AppColors.pending,
                    icon: Icons.note_alt,
                    subtitle: 'Hatırlatma notu',
                  ),
                ),
              if (notBorclarim > 0 && notAlacaklarim > 0)
                const SizedBox(width: AppConstants.smallPadding),
              if (notAlacaklarim > 0)
                Expanded(
                  child: _SummaryCard(
                    title: 'Not Alacaklarım',
                    amount: notAlacaklarim,
                    color: AppColors.info,
                    icon: Icons.note_alt,
                    subtitle: 'Hatırlatma notu',
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Tekil özet kartı
class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  final String subtitle;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppSizes.cardElevation,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: AppSizes.iconMedium),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              FormatUtils.formatCurrency(amount),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Net durum kartı
class NetBalanceCard extends StatelessWidget {
  final double borclarim;
  final double alacaklarim;
  final String contactName;

  const NetBalanceCard({
    super.key,
    required this.borclarim,
    required this.alacaklarim,
    required this.contactName,
  });

  @override
  Widget build(BuildContext context) {
    final netBalance = alacaklarim - borclarim;
    final isPositive = netBalance > 0;
    final isNeutral = netBalance == 0;

    return Card(
      elevation: AppSizes.cardElevation,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isNeutral
                ? [Colors.grey.withOpacity(0.1), Colors.grey.withOpacity(0.05)]
                : isPositive
                ? [
                    AppColors.success.withOpacity(0.1),
                    AppColors.success.withOpacity(0.05),
                  ]
                : [
                    AppColors.error.withOpacity(0.1),
                    AppColors.error.withOpacity(0.05),
                  ],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        (isNeutral
                                ? Colors.grey
                                : isPositive
                                ? AppColors.success
                                : AppColors.error)
                            .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isNeutral
                        ? Icons.balance
                        : isPositive
                        ? Icons.trending_up
                        : Icons.trending_down,
                    color: isNeutral
                        ? Colors.grey
                        : isPositive
                        ? AppColors.success
                        : AppColors.error,
                    size: AppSizes.iconLarge,
                  ),
                ),
                const SizedBox(width: AppConstants.defaultPadding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Durum',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusText(netBalance, contactName),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(
                  AppConstants.defaultBorderRadius,
                ),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
              child: Text(
                FormatUtils.formatCurrency(netBalance.abs()),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isNeutral
                      ? Colors.grey
                      : isPositive
                      ? AppColors.success
                      : AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(double netBalance, String contactName) {
    if (netBalance > 0) {
      return '$contactName size toplam ${FormatUtils.formatCurrency(netBalance)} borçlu';
    } else if (netBalance < 0) {
      return 'Siz $contactName\'e toplam ${FormatUtils.formatCurrency(netBalance.abs())} borçlusunuz';
    } else {
      return '$contactName ile aranızda borç bulunmuyor';
    }
  }
}
