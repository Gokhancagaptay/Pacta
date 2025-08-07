// lib/widgets/common/empty_state_widget.dart

import 'package:flutter/material.dart';
import 'package:pacta/constants/app_constants.dart';

/// Boş durum için ortak widget
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onActionPressed;
  final Widget? customAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onActionPressed,
    this.customAction,
  });

  /// Borç listesi boş durumu
  const EmptyStateWidget.noDebts({
    super.key,
    this.actionText,
    this.onActionPressed,
    this.customAction,
  }) : icon = Icons.account_balance_wallet_outlined,
       title = 'Henüz borç kaydınız yok',
       subtitle = 'İlk borcunuzu kaydetmek için aşağıdaki butona tıklayın.';

  /// Bildirim listesi boş durumu
  const EmptyStateWidget.noNotifications({super.key})
    : icon = Icons.notifications_none,
      title = 'Bildirim yok',
      subtitle = 'Şu anda herhangi bir bildiriminiz bulunmuyor.',
      actionText = null,
      onActionPressed = null,
      customAction = null;

  /// İletişim listesi boş durumu
  const EmptyStateWidget.noContacts({
    super.key,
    this.actionText,
    this.onActionPressed,
    this.customAction,
  }) : icon = Icons.people_outline,
       title = 'Kayıtlı kişi yok',
       subtitle = 'Hızlı erişim için kişilerinizi kaydedin.';

  /// Arama sonucu bulunamadı
  const EmptyStateWidget.noSearchResults({
    super.key,
    required String searchQuery,
  }) : icon = Icons.search_off,
       title = 'Sonuç bulunamadı',
       subtitle =
           '"$searchQuery" için sonuç bulunamadı. Farklı anahtar kelimeler deneyin.',
       actionText = null,
       onActionPressed = null,
       customAction = null;

  /// İnternet bağlantısı yok
  const EmptyStateWidget.noConnection({
    super.key,
    this.actionText = 'Tekrar Dene',
    this.onActionPressed,
  }) : icon = Icons.wifi_off,
       title = 'Bağlantı sorunu',
       subtitle = 'İnternet bağlantınızı kontrol edin ve tekrar deneyin.',
       customAction = null;

  /// Genel hata durumu
  const EmptyStateWidget.error({
    super.key,
    this.subtitle,
    this.actionText = 'Tekrar Dene',
    this.onActionPressed,
  }) : icon = Icons.error_outline,
       title = 'Bir hata oluştu',
       customAction = null;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(context),
            const SizedBox(height: AppConstants.defaultPadding),
            _buildTitle(context),
            if (subtitle != null) ...[
              const SizedBox(height: AppConstants.smallPadding),
              _buildSubtitle(context),
            ],
            if (actionText != null || customAction != null) ...[
              const SizedBox(height: AppConstants.largePadding),
              _buildAction(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: AppSizes.iconExtraLarge,
        color: Theme.of(context).primaryColor.withOpacity(0.7),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(
          context,
        ).textTheme.headlineSmall?.color?.withOpacity(0.8),
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    return Text(
      subtitle!,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildAction() {
    if (customAction != null) {
      return customAction!;
    }

    if (actionText != null && onActionPressed != null) {
      return ElevatedButton(
        onPressed: onActionPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.largePadding,
            vertical: AppConstants.smallPadding,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
          ),
        ),
        child: Text(actionText!),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Veri yükleme durumu widget'ı
class DataStateWidget extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final bool isEmpty;
  final String? errorMessage;
  final Widget child;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;

  const DataStateWidget({
    super.key,
    required this.isLoading,
    required this.hasError,
    required this.isEmpty,
    required this.child,
    this.errorMessage,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return loadingWidget ?? const Center(child: CircularProgressIndicator());
    }

    if (hasError) {
      return errorWidget ??
          EmptyStateWidget.error(
            subtitle: errorMessage,
            onActionPressed: () {
              // Bu durumda parent widget'ta refresh metodunu çağırmalı
            },
          );
    }

    if (isEmpty) {
      return emptyWidget ??
          const EmptyStateWidget(
            icon: Icons.inbox_outlined,
            title: 'Veri bulunamadı',
            subtitle: 'Gösterilecek veri bulunmuyor.',
          );
    }

    return child;
  }
}
