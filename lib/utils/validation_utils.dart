// lib/utils/validation_utils.dart

import 'package:pacta/constants/app_constants.dart';

/// Form validasyonu için yardımcı fonksiyonlar
class ValidationUtils {
  ValidationUtils._(); // Private constructor

  /// Email formatını kontrol eder
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Şifre güçlülüğünü kontrol eder
  static bool isValidPassword(String password) {
    if (password.length < AppConstants.minPasswordLength) return false;
    return true;
  }

  /// Telefon numarası formatını kontrol eder (Türkiye)
  static bool isValidPhone(String phone) {
    if (phone.isEmpty) return true; // Telefon opsiyonel
    // Türkiye telefon formatı: +90XXXXXXXXXX veya 05XXXXXXXXX
    return RegExp(r'^(\+90|0)?5\d{9}$').hasMatch(phone.replaceAll(' ', ''));
  }

  /// Ad soyad formatını kontrol eder
  static bool isValidName(String name) {
    if (name.isEmpty) return false;
    if (name.length > AppConstants.maxUsernameLength) return false;
    // En az 2 karakter, sadece harf ve boşluk
    return RegExp(r'^[a-zA-ZçğıöşüÇĞIİÖŞÜ\s]{2,}$').hasMatch(name);
  }

  /// Borç miktarını kontrol eder
  static bool isValidAmount(double amount) {
    return amount > 0 && amount <= AppConstants.maxDebtAmount;
  }

  /// Boş string kontrolü
  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  /// Email validation error mesajı
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'E-posta adresi gereklidir';
    }
    if (!isValidEmail(email)) {
      return 'Geçerli bir e-posta adresi girin';
    }
    return null;
  }

  /// Şifre validation error mesajı
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Şifre gereklidir';
    }
    if (!isValidPassword(password)) {
      return 'Şifre en az ${AppConstants.minPasswordLength} karakter olmalıdır';
    }
    return null;
  }

  /// Ad soyad validation error mesajı
  static String? validateName(String? name) {
    if (name == null || name.isEmpty) {
      return 'Ad soyad gereklidir';
    }
    if (!isValidName(name)) {
      return 'Geçerli bir ad soyad girin (en az 2 karakter)';
    }
    return null;
  }

  /// Telefon validation error mesajı
  static String? validatePhone(String? phone) {
    if (phone != null && phone.isNotEmpty && !isValidPhone(phone)) {
      return 'Geçerli bir telefon numarası girin';
    }
    return null;
  }

  /// Tutar validation error mesajı
  static String? validateAmount(String? amount) {
    if (amount == null || amount.isEmpty) {
      return 'Tutar gereklidir';
    }

    final parsedAmount = double.tryParse(amount);
    if (parsedAmount == null) {
      return 'Geçerli bir tutar girin';
    }

    if (!isValidAmount(parsedAmount)) {
      return 'Tutar 0 ile ${AppConstants.maxDebtAmount} arasında olmalıdır';
    }

    return null;
  }

  /// Açıklama validation error mesajı
  static String? validateDescription(String? description) {
    if (description != null && description.length > 500) {
      return 'Açıklama en fazla 500 karakter olabilir';
    }
    return null;
  }
}
