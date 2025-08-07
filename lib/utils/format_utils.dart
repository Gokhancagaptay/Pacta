// lib/utils/format_utils.dart

import 'package:intl/intl.dart';
import 'package:pacta/constants/app_constants.dart';

/// Formatlama işlemleri için yardımcı fonksiyonlar
class FormatUtils {
  FormatUtils._(); // Private constructor

  /// Para formatı: 1234.56 -> "1.234,56₺"
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Kısa para formatı: 1234567 -> "1.2M₺"
  static String formatCurrencyShort(double amount) {
    if (amount.abs() >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M₺';
    }
    if (amount.abs() >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K₺';
    }
    return formatCurrency(amount);
  }

  /// Tarih formatı: DateTime -> "25/12/2023"
  static String formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat(AppConstants.defaultDateFormat).format(date);
  }

  /// Tarih saat formatı: DateTime -> "25/12/2023 14:30"
  static String formatDateTime(DateTime? date) {
    if (date == null) return '';
    return DateFormat(AppConstants.defaultDateTimeFormat).format(date);
  }

  /// API tarih formatı: DateTime -> "2023-12-25"
  static String formatDateForApi(DateTime? date) {
    if (date == null) return '';
    return DateFormat(AppConstants.apiDateFormat).format(date);
  }

  /// Göreceli zaman: DateTime -> "2 saat önce"
  static String formatRelativeTime(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} yıl önce';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} ay önce';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Şimdi';
    }
  }

  /// Telefon formatı: "05551234567" -> "+90 555 123 45 67"
  static String formatPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';

    // Türkiye telefon formatı
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanPhone.length == 11 && cleanPhone.startsWith('0')) {
      // 05551234567 -> +90 555 123 45 67
      return '+90 ${cleanPhone.substring(1, 4)} ${cleanPhone.substring(4, 7)} ${cleanPhone.substring(7, 9)} ${cleanPhone.substring(9)}';
    } else if (cleanPhone.length == 10) {
      // 5551234567 -> +90 555 123 45 67
      return '+90 ${cleanPhone.substring(0, 3)} ${cleanPhone.substring(3, 6)} ${cleanPhone.substring(6, 8)} ${cleanPhone.substring(8)}';
    }

    return phone; // Formatlanamadıysa orijinal döndür
  }

  /// İlk harf büyük: "ahmet" -> "Ahmet"
  static String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Her kelimenin ilk harfi büyük: "ahmet mehmet" -> "Ahmet Mehmet"
  static String capitalizeWords(String? text) {
    if (text == null || text.isEmpty) return '';
    return text.split(' ').map((word) => capitalize(word)).join(' ');
  }

  /// Kısaltma: "Ahmet Mehmet" -> "AM"
  static String getInitials(String? name) {
    if (name == null || name.isEmpty) return '';

    final words = name.trim().split(' ');
    String initials = '';

    for (int i = 0; i < words.length && i < 2; i++) {
      if (words[i].isNotEmpty) {
        initials += words[i][0].toUpperCase();
      }
    }

    return initials;
  }

  /// Dosya boyutu formatı: 1024 -> "1 KB"
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (bytes.bitLength - 1) ~/ 10;

    if (i >= suffixes.length) return '${bytes} B';

    return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Yüzde formatı: 0.75 -> "%75"
  static String formatPercentage(double value) {
    return '%${(value * 100).toStringAsFixed(0)}';
  }

  /// Durum metni formatı
  static String formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Bekliyor';
      case 'approved':
        return 'Onaylandı';
      case 'rejected':
        return 'Reddedildi';
      case 'note':
        return 'Not';
      case 'pending_deletion':
        return 'Silme Bekliyor';
      default:
        return capitalize(status);
    }
  }

  /// Maskeli telefon: "05551234567" -> "0555***4567"
  static String maskPhone(String? phone) {
    if (phone == null || phone.length < 7) return phone ?? '';

    final start = phone.substring(0, 4);
    final end = phone.substring(phone.length - 4);
    return '$start***$end';
  }

  /// Maskeli email: "test@example.com" -> "t***@example.com"
  static String maskEmail(String? email) {
    if (email == null || !email.contains('@')) return email ?? '';

    final parts = email.split('@');
    if (parts[0].length <= 2) return email;

    final start = parts[0][0];
    final domain = parts[1];
    return '$start***@$domain';
  }
}
