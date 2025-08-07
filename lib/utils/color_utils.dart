// lib/utils/color_utils.dart

import 'package:flutter/material.dart';
import 'package:pacta/constants/app_constants.dart';

/// Tema-aware renk yardımcı fonksiyonları
class ColorUtils {
  ColorUtils._(); // Private constructor

  /// Transaction status'a göre renk döndürür
  static Color getStatusColor(String status, {BuildContext? context}) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.approved;
      case 'pending':
        return AppColors.pending;
      case 'rejected':
        return AppColors.rejected;
      case 'note':
        return AppColors.info;
      case 'pending_deletion':
        return AppColors.warning;
    }

    // Fallback to theme color
    return context != null
        ? Theme.of(context).colorScheme.primary
        : AppColors.lightPrimary;
  }

  /// Transaction türüne göre renk döndürür
  static Color getTransactionTypeColor(
    bool isDebt,
    String status, {
    BuildContext? context,
  }) {
    if (status.toLowerCase() == 'note') {
      return AppColors.info;
    }

    return isDebt ? AppColors.debt : AppColors.credit;
  }

  /// Chart için renk döndürür
  static Color getChartColor(int index) {
    const chartColors = [
      Color(0xFF6366F1), // Indigo
      Color(0xFF10B981), // Emerald
      Color(0xFFF59E0B), // Amber
      Color(0xFFEF4444), // Red
      Color(0xFF8B5CF6), // Violet
      Color(0xFF06B6D4), // Cyan
      Color(0xFFF97316), // Orange
      Color(0xFF84CC16), // Lime
    ];
    return chartColors[index % chartColors.length];
  }

  /// Success işlemleri için renk
  static Color getSuccessColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.success.withOpacity(0.8)
        : AppColors.success;
  }

  /// Error işlemleri için renk
  static Color getErrorColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.error.withOpacity(0.8)
        : AppColors.error;
  }

  /// Warning işlemleri için renk
  static Color getWarningColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.warning.withOpacity(0.8)
        : AppColors.warning;
  }

  /// Info işlemleri için renk
  static Color getInfoColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.info.withOpacity(0.8)
        : AppColors.info;
  }

  /// Background rengine göre kontrast metin rengi
  static Color getContrastColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Tema-aware card background rengi
  static Color getCardBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
  }

  /// Tema-aware divider rengi
  static Color getDividerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white12
        : Colors.black12;
  }

  /// Amount için renk (pozitif/negatif)
  static Color getAmountColor(
    double amount,
    BuildContext context, {
    bool isDebt = false,
  }) {
    if (amount == 0) {
      return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    }

    if (isDebt) {
      return amount > 0 ? AppColors.debt : AppColors.credit;
    }

    return amount > 0 ? AppColors.credit : AppColors.debt;
  }

  /// Gradient renkler
  static LinearGradient getStatusGradient(String status) {
    final baseColor = getStatusColor(status);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [baseColor.withOpacity(0.1), baseColor.withOpacity(0.05)],
    );
  }

  /// Shimmer effect renkleri
  static List<Color> getShimmerColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return [Colors.grey[800]!, Colors.grey[700]!, Colors.grey[800]!];
    } else {
      return [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!];
    }
  }

  /// Priority rengi
  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.info;
      default:
        return Colors.grey;
    }
  }

  /// Percentage color (0-100%)
  static Color getPercentageColor(double percentage) {
    if (percentage >= 80) {
      return AppColors.success;
    } else if (percentage >= 60) {
      return AppColors.info;
    } else if (percentage >= 40) {
      return AppColors.warning;
    } else {
      return AppColors.error;
    }
  }

  /// Material You dynamic color support
  static ColorScheme? getDynamicColorScheme(BuildContext context) {
    // Bu fonksiyon gelecekte Material You dynamic colors için kullanılabilir
    return null;
  }

  /// Color with opacity based on theme
  static Color getThemedColor(
    Color lightColor,
    Color darkColor,
    BuildContext context,
  ) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkColor
        : lightColor;
  }
}
