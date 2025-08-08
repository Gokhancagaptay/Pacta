// lib/utils/dialog_utils.dart

import 'package:flutter/material.dart';
import 'package:pacta/constants/app_constants.dart';

/// Dialog ve SnackBar işlemleri için yardımcı fonksiyonlar
class DialogUtils {
  DialogUtils._(); // Private constructor

  static SnackBar _buildSnackBar(
    BuildContext context,
    String message,
    IconData icon,
    Color accent, {
    Duration duration = const Duration(seconds: 3),
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark
        ? const Color(0xFFE6E8EB)
        : const Color(0xFF1A202C);

    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: AppConstants.smallPadding),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: bgColor,
      elevation: 6,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: duration,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        side: BorderSide(color: accent.withValues(alpha: 0.35), width: 1),
      ),
    );
  }

  /// Loading dialog göster
  static void showLoading(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: AppConstants.defaultPadding),
            Expanded(
              child: Text(
                message ?? 'Yükleniyor...',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Loading dialog'u kapat
  static void hideLoading(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// Başarı mesajı göster
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    final bar = _buildSnackBar(
      context,
      message,
      Icons.check_circle_rounded,
      AppColors.success,
      duration: duration,
    );
    ScaffoldMessenger.of(context).showSnackBar(bar);
  }

  /// Hata mesajı göster
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final bar = _buildSnackBar(
      context,
      message,
      Icons.error_outline,
      AppColors.error,
      duration: duration,
    );
    ScaffoldMessenger.of(context).showSnackBar(bar);
  }

  /// Uyarı mesajı göster
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    final bar = _buildSnackBar(
      context,
      message,
      Icons.warning_amber_rounded,
      AppColors.warning,
      duration: duration,
    );
    ScaffoldMessenger.of(context).showSnackBar(bar);
  }

  /// Bilgi mesajı göster
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    final bar = _buildSnackBar(
      context,
      message,
      Icons.info_outline,
      AppColors.info,
      duration: duration,
    );
    ScaffoldMessenger.of(context).showSnackBar(bar);
  }

  /// Onay dialog'u göster
  static Future<bool> showConfirmation(
    BuildContext context,
    String title,
    String message, {
    String confirmText = 'Evet',
    String cancelText = 'İptal',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: confirmColor != null
                ? ElevatedButton.styleFrom(backgroundColor: confirmColor)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Silme onayı dialog'u
  static Future<bool> showDeleteConfirmation(
    BuildContext context,
    String itemName,
  ) async {
    return await showConfirmation(
      context,
      'Silme Onayı',
      '$itemName silinecek. Bu işlem geri alınamaz. Emin misiniz?',
      confirmText: 'Sil',
      cancelText: 'İptal',
      confirmColor: AppColors.error,
    );
  }

  /// Çıkış onayı dialog'u
  static Future<bool> showLogoutConfirmation(BuildContext context) async {
    return await showConfirmation(
      context,
      'Çıkış Onayı',
      'Uygulamadan çıkış yapmak istediğinizden emin misiniz?',
      confirmText: 'Çıkış Yap',
      cancelText: 'İptal',
    );
  }

  /// Seçim dialog'u göster
  static Future<T?> showSelectionDialog<T>(
    BuildContext context,
    String title,
    List<T> items,
    String Function(T) itemBuilder, {
    T? selectedItem,
  }) async {
    return await showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = item == selectedItem;

              return ListTile(
                title: Text(itemBuilder(item)),
                trailing: isSelected ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(item),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
        ],
      ),
    );
  }

  /// Input dialog'u göster
  static Future<String?> showInputDialog(
    BuildContext context,
    String title,
    String hintText, {
    String? initialValue,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              border: const OutlineInputBorder(),
            ),
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(controller.text);
              }
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet göster
  static Future<T?> showCustomBottomSheet<T>(
    BuildContext context,
    Widget child, {
    bool isDismissible = true,
    bool enableDrag = true,
  }) async {
    return await showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.defaultBorderRadius),
        ),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: child,
      ),
    );
  }
}
