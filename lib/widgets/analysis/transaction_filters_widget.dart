// lib/widgets/analysis/transaction_filters_widget.dart

import 'package:flutter/material.dart';
import 'package:pacta/constants/app_constants.dart';

/// İşlem filtreleme widget'ı
class TransactionFiltersWidget extends StatelessWidget {
  final String selectedTransactionType;
  final String selectedStatus;
  final String selectedDateRange;
  final DateTimeRange? customDateRange;
  final Function(String) onTransactionTypeChanged;
  final Function(String) onStatusChanged;
  final Function(String) onDateRangeChanged;
  final Function(DateTimeRange?) onCustomDateRangeChanged;

  const TransactionFiltersWidget({
    super.key,
    required this.selectedTransactionType,
    required this.selectedStatus,
    required this.selectedDateRange,
    required this.customDateRange,
    required this.onTransactionTypeChanged,
    required this.onStatusChanged,
    required this.onDateRangeChanged,
    required this.onCustomDateRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppSizes.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: Theme.of(context).primaryColor),
                const SizedBox(width: AppConstants.smallPadding),
                Text(
                  'Filtreler',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),

            // İşlem türü filtresi
            _buildFilterSection(
              context,
              title: 'İşlem Türü',
              selectedValue: selectedTransactionType,
              options: const ['Tümü', 'Borç', 'Alacak'],
              onChanged: onTransactionTypeChanged,
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Durum filtresi
            _buildFilterSection(
              context,
              title: 'Durum',
              selectedValue: selectedStatus,
              options: const ['Tümü', 'Onaylanmış', 'Not'],
              onChanged: onStatusChanged,
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Tarih filtresi
            _buildDateFilterSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(
    BuildContext context, {
    required String title,
    required String selectedValue,
    required List<String> options,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: AppConstants.smallPadding),
        Wrap(
          spacing: AppConstants.smallPadding,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onChanged(option);
                }
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              checkmarkColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateFilterSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tarih Aralığı',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: AppConstants.smallPadding),
        Wrap(
          spacing: AppConstants.smallPadding,
          runSpacing: AppConstants.smallPadding,
          children: [
            ...[
              'Tüm Zamanlar',
              'Son 7 Gün',
              'Son 30 Gün',
              'Son 3 Ay',
              'Son 6 Ay',
              'Son 1 Yıl',
            ].map((option) {
              final isSelected = selectedDateRange == option;
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    onDateRangeChanged(option);
                    if (option != 'Özel Aralık') {
                      onCustomDateRangeChanged(null);
                    }
                  }
                },
                selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                checkmarkColor: Theme.of(context).primaryColor,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }),

            // Özel tarih aralığı butonu
            OutlinedButton.icon(
              onPressed: () => _showCustomDateRangePicker(context),
              icon: const Icon(Icons.date_range),
              label: Text(
                selectedDateRange == 'Özel Aralık' && customDateRange != null
                    ? 'Özel: ${_formatDateRange(customDateRange!)}'
                    : 'Özel Aralık',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: selectedDateRange == 'Özel Aralık'
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).textTheme.bodyMedium?.color,
                side: BorderSide(
                  color: selectedDateRange == 'Özel Aralık'
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).dividerColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showCustomDateRangePicker(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: customDateRange,
    );

    if (picked != null) {
      onCustomDateRangeChanged(picked);
      onDateRangeChanged('Özel Aralık');
    }
  }

  String _formatDateRange(DateTimeRange range) {
    final startDate = range.start;
    final endDate = range.end;
    return '${startDate.day}/${startDate.month} - ${endDate.day}/${endDate.month}';
  }
}
