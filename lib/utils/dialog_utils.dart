// lib/utils/dialog_utils.dart

import 'package:flutter/material.dart';
import 'package:pacta/constants/app_constants.dart';

/// Dialog ve SnackBar işlemleri için yardımcı fonksiyonlar
class DialogUtils {
  DialogUtils._(); // Private constructor

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: AppConstants.smallPadding),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success.withOpacity(0.1),
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Hata mesajı göster
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: AppColors.error),
            const SizedBox(width: AppConstants.smallPadding),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error.withOpacity(0.1),
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Uyarı mesajı göster
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: AppColors.warning),
            const SizedBox(width: AppConstants.smallPadding),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.warning.withOpacity(0.1),
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Bilgi mesajı göster
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: AppColors.info),
            const SizedBox(width: AppConstants.smallPadding),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.info.withOpacity(0.1),
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
