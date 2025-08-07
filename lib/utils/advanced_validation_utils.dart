// lib/utils/advanced_validation_utils.dart

import 'package:flutter/services.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:pacta/utils/validation_utils.dart';

/// Gelişmiş validation ve input formatters
class AdvancedValidationUtils {
  AdvancedValidationUtils._(); // Private constructor

  /// Türkiye IBAN validation
  static bool isValidTurkishIBAN(String iban) {
    if (iban.isEmpty) return false;

    // Remove spaces and convert to uppercase
    final cleanIban = iban.replaceAll(' ', '').toUpperCase();

    // Turkish IBAN format: TR + 2 check digits + 26 digits
    if (!RegExp(r'^TR\d{24}$').hasMatch(cleanIban)) {
      return false;
    }

    // IBAN mod-97 check
    return _validateIBANChecksum(cleanIban);
  }

  /// TC Kimlik No validation
  static bool isValidTCKimlikNo(String tcKimlik) {
    if (tcKimlik.isEmpty || tcKimlik.length != 11) return false;

    final digits = tcKimlik.split('').map((e) => int.tryParse(e)).toList();
    if (digits.any((element) => element == null)) return false;

    final digitList = digits.cast<int>();

    // First digit cannot be 0
    if (digitList[0] == 0) return false;

    // 10th digit validation
    final sum1 =
        digitList[0] +
        digitList[2] +
        digitList[4] +
        digitList[6] +
        digitList[8];
    final sum2 = digitList[1] + digitList[3] + digitList[5] + digitList[7];
    final tenthDigit = ((sum1 * 7) - sum2) % 10;

    if (tenthDigit != digitList[9]) return false;

    // 11th digit validation
    final totalSum = digitList.take(10).reduce((a, b) => a + b);
    final eleventhDigit = totalSum % 10;

    return eleventhDigit == digitList[10];
  }

  /// Güçlü şifre validation
  static bool isStrongPassword(String password) {
    if (password.length < 8) return false;

    final hasUpperCase = password.contains(RegExp(r'[A-Z]'));
    final hasLowerCase = password.contains(RegExp(r'[a-z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecialCharacters = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );

    return hasUpperCase && hasLowerCase && hasDigits && hasSpecialCharacters;
  }

  /// Credit card validation (Luhn algorithm)
  static bool isValidCreditCard(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(' ', '');
    if (cleanNumber.length < 13 || cleanNumber.length > 19) return false;

    int sum = 0;
    bool alternate = false;

    for (int i = cleanNumber.length - 1; i >= 0; i--) {
      int digit = int.tryParse(cleanNumber[i]) ?? 0;

      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit = (digit % 10) + 1;
        }
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  /// URL validation
  static bool isValidURL(String url) {
    if (url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Turkish phone number formatter
  static TextInputFormatter get turkishPhoneFormatter {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

      if (text.isEmpty) return newValue;

      String formatted = '';
      if (text.length >= 1) {
        formatted += text.substring(0, 1); // 0
      }
      if (text.length >= 4) {
        formatted += ' ${text.substring(1, 4)}'; // 5XX
      }
      if (text.length >= 7) {
        formatted += ' ${text.substring(4, 7)}'; // XXX
      }
      if (text.length >= 9) {
        formatted += ' ${text.substring(7, 9)}'; // XX
      }
      if (text.length >= 11) {
        formatted += ' ${text.substring(9, 11)}'; // XX
      }

      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
  }

  /// IBAN formatter
  static TextInputFormatter get ibanFormatter {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text.replaceAll(' ', '').toUpperCase();

      if (text.isEmpty) return newValue;

      String formatted = '';
      for (int i = 0; i < text.length; i += 4) {
        if (i > 0) formatted += ' ';
        formatted += text.substring(
          i,
          (i + 4 > text.length) ? text.length : i + 4,
        );
      }

      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
  }

  /// Currency formatter (Turkish Lira)
  static TextInputFormatter get currencyFormatter {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      if (newValue.text.isEmpty) return newValue;

      final text = newValue.text.replaceAll(RegExp(r'[^\d.,]'), '');

      // Replace comma with dot for decimal
      final normalizedText = text.replaceAll(',', '.');

      // Check if valid number
      final number = double.tryParse(normalizedText);
      if (number == null) return oldValue;

      // Check max amount
      if (number > AppConstants.maxDebtAmount) {
        return oldValue;
      }

      return TextEditingValue(
        text: normalizedText,
        selection: TextSelection.collapsed(offset: normalizedText.length),
      );
    });
  }

  /// Credit card formatter
  static TextInputFormatter get creditCardFormatter {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text.replaceAll(' ', '');

      if (text.isEmpty) return newValue;

      String formatted = '';
      for (int i = 0; i < text.length; i += 4) {
        if (i > 0) formatted += ' ';
        formatted += text.substring(
          i,
          (i + 4 > text.length) ? text.length : i + 4,
        );
      }

      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
  }

  /// Advanced email validation
  static String? validateAdvancedEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'E-posta adresi gereklidir';
    }

    if (!ValidationUtils.isValidEmail(email)) {
      return 'Geçerli bir e-posta adresi girin';
    }

    // Check for common typos
    final domain = email.split('@').last.toLowerCase();

    // Suggest corrections for common typos
    if (domain.contains('gmial') || domain.contains('gmai')) {
      return 'Gmail kullanmak istediğinizden emin misiniz? (gmail.com)';
    }

    if (domain.contains('hotmial') || domain.contains('hotmai')) {
      return 'Hotmail kullanmak istediğinizden emin misiniz? (hotmail.com)';
    }

    return null;
  }

  /// Advanced phone validation
  static String? validateAdvancedPhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return 'Telefon numarası gereklidir';
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanPhone.length != 11) {
      return 'Telefon numarası 11 haneli olmalıdır';
    }

    if (!cleanPhone.startsWith('0')) {
      return 'Telefon numarası 0 ile başlamalıdır';
    }

    if (!cleanPhone.substring(1, 2).contains(RegExp(r'[5]'))) {
      return 'Geçerli bir cep telefonu numarası girin (05XX)';
    }

    return null;
  }

  /// Advanced amount validation
  static String? validateAdvancedAmount(String? amount) {
    if (amount == null || amount.isEmpty) {
      return 'Tutar gereklidir';
    }

    final normalizedAmount = amount.replaceAll(',', '.');
    final parsedAmount = double.tryParse(normalizedAmount);

    if (parsedAmount == null) {
      return 'Geçerli bir tutar girin';
    }

    if (parsedAmount <= 0) {
      return 'Tutar sıfırdan büyük olmalıdır';
    }

    if (parsedAmount > AppConstants.maxDebtAmount) {
      return 'Tutar ${AppConstants.maxDebtAmount}₺ dan fazla olamaz';
    }

    // Check for suspicious amounts
    if (parsedAmount > 100000) {
      return 'Bu kadar büyük bir tutar için onay gerekiyor';
    }

    return null;
  }

  /// IBAN checksum validation
  static bool _validateIBANChecksum(String iban) {
    // Move first 4 characters to end
    final rearranged = iban.substring(4) + iban.substring(0, 4);

    // Replace letters with numbers (A=10, B=11, ..., Z=35)
    String numeric = '';
    for (int i = 0; i < rearranged.length; i++) {
      final char = rearranged[i];
      if (RegExp(r'[A-Z]').hasMatch(char)) {
        numeric += (char.codeUnitAt(0) - 55).toString();
      } else {
        numeric += char;
      }
    }

    // Calculate mod 97
    return _mod97(numeric) == 1;
  }

  /// Mod 97 calculation for large numbers
  static int _mod97(String number) {
    int remainder = 0;
    for (int i = 0; i < number.length; i++) {
      remainder = (remainder * 10 + int.parse(number[i])) % 97;
    }
    return remainder;
  }

  /// Input sanitization for XSS prevention
  static String sanitizeInput(String input) {
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('&', '&amp;');
  }

  /// SQL injection prevention
  static String sanitizeForDatabase(String input) {
    return input
        .replaceAll("'", "''")
        .replaceAll('"', '""')
        .replaceAll(';', '')
        .replaceAll('--', '')
        .replaceAll('/*', '')
        .replaceAll('*/', '');
  }
}
