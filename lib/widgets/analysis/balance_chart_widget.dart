// lib/widgets/analysis/balance_chart_widget.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:pacta/utils/format_utils.dart';

/// Borç/Alacak denge grafiği widget'ı
class BalanceChartWidget extends StatelessWidget {
  final double borclarim;
  final double alacaklarim;
  final Function(int)? onTouchedIndexChanged;
  final int? touchedIndex;

  const BalanceChartWidget({
    super.key,
    required this.borclarim,
    required this.alacaklarim,
    this.onTouchedIndexChanged,
    this.touchedIndex,
  });

  @override
  Widget build(BuildContext context) {
    final total = borclarim + alacaklarim;
    if (total == 0) {
      return _buildEmptyChart(context);
    }

    return AspectRatio(
      aspectRatio: 1.2,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              if (event is FlTapUpEvent &&
                  pieTouchResponse?.touchedSection != null) {
                final index =
                    pieTouchResponse!.touchedSection!.touchedSectionIndex;
                onTouchedIndexChanged?.call(index);
              }
            },
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 2,
          centerSpaceRadius: 50,
          sections: _buildPieChartSections(context),
        ),
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: AppSizes.iconExtraLarge,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              'Veri bulunmuyor',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(BuildContext context) {
    final total = borclarim + alacaklarim;
    final List<PieChartSectionData> sections = [];

    if (borclarim > 0) {
      sections.add(
        PieChartSectionData(
          color: AppColors.debt,
          value: borclarim,
          title: touchedIndex == sections.length
              ? '${FormatUtils.formatPercentage(borclarim / total)}\n${FormatUtils.formatCurrency(borclarim)}'
              : FormatUtils.formatPercentage(borclarim / total),
          radius: touchedIndex == sections.length ? 65 : 55,
          titleStyle: TextStyle(
            fontSize: touchedIndex == sections.length ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (alacaklarim > 0) {
      sections.add(
        PieChartSectionData(
          color: AppColors.credit,
          value: alacaklarim,
          title: touchedIndex == sections.length
              ? '${FormatUtils.formatPercentage(alacaklarim / total)}\n${FormatUtils.formatCurrency(alacaklarim)}'
              : FormatUtils.formatPercentage(alacaklarim / total),
          radius: touchedIndex == sections.length ? 65 : 55,
          titleStyle: TextStyle(
            fontSize: touchedIndex == sections.length ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return sections;
  }
}

/// Grafik açıklama widget'ı
class ChartLegendWidget extends StatelessWidget {
  final double borclarim;
  final double alacaklarim;

  const ChartLegendWidget({
    super.key,
    required this.borclarim,
    required this.alacaklarim,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (borclarim > 0)
          _buildLegendItem(
            context,
            color: AppColors.debt,
            label: 'Borçlarım',
            value: borclarim,
          ),
        if (alacaklarim > 0) ...[
          if (borclarim > 0) const SizedBox(height: AppConstants.smallPadding),
          _buildLegendItem(
            context,
            color: AppColors.credit,
            label: 'Alacaklarım',
            value: alacaklarim,
          ),
        ],
      ],
    );
  }

  Widget _buildLegendItem(
    BuildContext context, {
    required Color color,
    required String label,
    required double value,
  }) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: AppConstants.smallPadding),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          FormatUtils.formatCurrency(value),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
