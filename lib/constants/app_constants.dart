// lib/constants/app_constants.dart

import 'package:flutter/material.dart';

/// Uygulama genelinde kullanılan sabit değerler
class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  // App Info
  static const String appName = 'Pacta';
  static const String appVersion = '1.0.0';

  // Theme Colors
  static const Color primaryColor = Colors.deepPurple;
  static const Color secondaryColor = Color(0xFF6C63FF);
  static const Color errorColor = Color(0xFFE57373);
  static const Color successColor = Color(0xFF81C784);
  static const Color warningColor = Color(0xFFFFB74D);

  // Animations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);

  // Dimensions
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;

  // API & Database
  static const int queryLimit = 50;
  static const int maxRetryAttempts = 3;
  static const Duration requestTimeout = Duration(seconds: 30);

  // Validation
  static const int minPasswordLength = 6;
  static const int maxUsernameLength = 50;
  static const double maxDebtAmount = 999999.99;

  // File & Image
  static const int maxFileSize = 10 * 1024 * 1024; // 10 MB
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png'];

  // Date Formats
  static const String defaultDateFormat = 'dd/MM/yyyy';
  static const String defaultDateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String apiDateFormat = 'yyyy-MM-dd';

  // Error Messages
  static const String genericError =
      'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
  static const String networkError = 'İnternet bağlantınızı kontrol edin.';
  static const String timeoutError =
      'İşlem zaman aşımına uğradı. Lütfen tekrar deneyin.';
  static const String unauthorizedError =
      'Bu işlemi gerçekleştirmek için yetkiniz yok.';

  // Success Messages
  static const String saveSuccess = 'Başarıyla kaydedildi.';
  static const String updateSuccess = 'Başarıyla güncellendi.';
  static const String deleteSuccess = 'Başarıyla silindi.';

  // Form Labels
  static const String emailLabel = 'E-posta';
  static const String passwordLabel = 'Şifre';
  static const String nameLabel = 'Ad Soyad';
  static const String phoneLabel = 'Telefon';
  static const String amountLabel = 'Tutar';
  static const String descriptionLabel = 'Açıklama';

  // Button Labels
  static const String saveLabel = 'Kaydet';
  static const String cancelLabel = 'İptal';
  static const String deleteLabel = 'Sil';
  static const String editLabel = 'Düzenle';
  static const String loginLabel = 'Giriş Yap';
  static const String registerLabel = 'Kayıt Ol';
  static const String logoutLabel = 'Çıkış Yap';

  // Status Values
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';
  static const String statusNote = 'note';
  static const String statusPendingDeletion = 'pending_deletion';

  // Collection Names
  static const String usersCollection = 'users';
  static const String debtsCollection = 'debts';
  static const String notificationsCollection = 'notifications';
  static const String savedContactsCollection = 'savedContacts';

  // Notification Types
  static const String notificationTypeApprovalRequest = 'approval_request';
  static const String notificationTypeRequestApproved = 'request_approved';
  static const String notificationTypeRequestRejected = 'request_rejected';
  static const String notificationTypeDeletionRequest = 'deletion_request';

  // Preferences Keys
  static const String themePreferenceKey = 'theme_mode';
  static const String languagePreferenceKey = 'language_code';
  static const String notificationPreferenceKey = 'notifications_enabled';
}

/// Uygulama renklerini içeren sınıf
class AppColors {
  AppColors._();

  // Light Theme Colors
  static const Color lightPrimary = Color(0xFF673AB7);
  static const Color lightPrimaryVariant = Color(0xFF512DA8);
  static const Color lightSecondary = Color(0xFF6C63FF);
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightError = Color(0xFFB00020);

  // Dark Theme Colors
  static const Color darkPrimary = Color(0xFF7986CB);
  static const Color darkPrimaryVariant = Color(0xFF5C6BC0);
  static const Color darkSecondary = Color(0xFF6C63FF);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkError = Color(0xFFCF6679);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);
  static const Color error = Color(0xFFF44336);

  // Semantic Colors
  static const Color debt = Color(0xFFE57373);
  static const Color credit = Color(0xFF81C784);
  static const Color pending = Color(0xFFFFB74D);
  static const Color approved = Color(0xFF81C784);
  static const Color rejected = Color(0xFFE57373);

  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Violet
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFF84CC16), // Lime
  ];

  // Transaction Status Colors
  static const Map<String, Color> statusColors = {
    'approved': approved,
    'pending': pending,
    'rejected': rejected,
    'note': info,
    'pending_deletion': warning,
  };
}

/// Uygulama boyutlarını içeren sınıf
class AppSizes {
  AppSizes._();

  // Icon Sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconExtraLarge = 48.0;

  // Font Sizes
  static const double fontSmall = 12.0;
  static const double fontMedium = 14.0;
  static const double fontLarge = 16.0;
  static const double fontExtraLarge = 18.0;
  static const double fontTitle = 20.0;
  static const double fontHeading = 24.0;

  // Button Heights
  static const double buttonSmall = 36.0;
  static const double buttonMedium = 48.0;
  static const double buttonLarge = 56.0;

  // Card & Container
  static const double cardElevation = 2.0;
  static const double containerMinHeight = 60.0;
  static const double listItemHeight = 72.0;
}
