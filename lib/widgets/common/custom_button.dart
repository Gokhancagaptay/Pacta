// lib/widgets/common/custom_button.dart

import 'package:flutter/material.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:pacta/widgets/common/loading_widget.dart';

/// Özelleştirilebilir buton widget'ı
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final ButtonType type;
  final ButtonSize size;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final Widget? child;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.child,
  });

  /// Primary buton (filled)
  const CustomButton.primary({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.size = ButtonSize.medium,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.child,
  }) : type = ButtonType.primary;

  /// Secondary buton (outlined)
  const CustomButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.size = ButtonSize.medium,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.child,
  }) : type = ButtonType.secondary;

  /// Text buton
  const CustomButton.text({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.size = ButtonSize.medium,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.child,
  }) : type = ButtonType.text;

  /// Danger buton (kırmızı)
  const CustomButton.danger({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.size = ButtonSize.medium,
    this.textColor,
    this.icon,
    this.child,
  }) : type = ButtonType.danger,
       backgroundColor = AppColors.error;

  /// Success buton (yeşil)
  const CustomButton.success({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.size = ButtonSize.medium,
    this.textColor,
    this.icon,
    this.child,
  }) : type = ButtonType.success,
       backgroundColor = AppColors.success;

  @override
  Widget build(BuildContext context) {
    final isDisabled = !isEnabled || isLoading || onPressed == null;

    switch (type) {
      case ButtonType.primary:
        return _buildElevatedButton(context, isDisabled);
      case ButtonType.secondary:
        return _buildOutlinedButton(context, isDisabled);
      case ButtonType.text:
        return _buildTextButton(context, isDisabled);
      case ButtonType.danger:
      case ButtonType.success:
        return _buildElevatedButton(context, isDisabled);
    }
  }

  Widget _buildElevatedButton(BuildContext context, bool isDisabled) {
    return ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? _getButtonColor(context),
        foregroundColor: textColor ?? _getTextColor(context),
        minimumSize: Size(double.infinity, _getButtonHeight()),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
        elevation: isDisabled ? 0 : 1,
      ),
      child: _buildButtonContent(context),
    );
  }

  Widget _buildOutlinedButton(BuildContext context, bool isDisabled) {
    return OutlinedButton(
      onPressed: isDisabled ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: backgroundColor ?? Theme.of(context).primaryColor,
        side: BorderSide(
          color: backgroundColor ?? Theme.of(context).primaryColor,
        ),
        minimumSize: Size(double.infinity, _getButtonHeight()),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
      ),
      child: _buildButtonContent(context),
    );
  }

  Widget _buildTextButton(BuildContext context, bool isDisabled) {
    return TextButton(
      onPressed: isDisabled ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: textColor ?? Theme.of(context).primaryColor,
        minimumSize: Size(double.infinity, _getButtonHeight()),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
      ),
      child: _buildButtonContent(context),
    );
  }

  Widget _buildButtonContent(BuildContext context) {
    if (isLoading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SmallLoadingWidget(
            color: type == ButtonType.secondary || type == ButtonType.text
                ? Theme.of(context).primaryColor
                : Colors.white,
          ),
          const SizedBox(width: AppConstants.smallPadding),
          Text(_getLoadingText()),
        ],
      );
    }

    if (child != null) {
      return child!;
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _getIconSize()),
          const SizedBox(width: AppConstants.smallPadding),
          Text(text, style: _getTextStyle(context)),
        ],
      );
    }

    return Text(text, style: _getTextStyle(context));
  }

  Color? _getButtonColor(BuildContext context) {
    switch (type) {
      case ButtonType.danger:
        return AppColors.error;
      case ButtonType.success:
        return AppColors.success;
      default:
        return backgroundColor;
    }
  }

  Color? _getTextColor(BuildContext context) {
    if (textColor != null) return textColor;

    switch (type) {
      case ButtonType.secondary:
      case ButtonType.text:
        return Theme.of(context).primaryColor;
      default:
        return Colors.white;
    }
  }

  double _getButtonHeight() {
    switch (size) {
      case ButtonSize.small:
        return AppSizes.buttonSmall;
      case ButtonSize.medium:
        return AppSizes.buttonMedium;
      case ButtonSize.large:
        return AppSizes.buttonLarge;
    }
  }

  double _getIconSize() {
    switch (size) {
      case ButtonSize.small:
        return AppSizes.iconSmall;
      case ButtonSize.medium:
        return AppSizes.iconMedium;
      case ButtonSize.large:
        return AppSizes.iconLarge;
    }
  }

  TextStyle _getTextStyle(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.labelLarge;

    switch (size) {
      case ButtonSize.small:
        return baseStyle?.copyWith(fontSize: AppSizes.fontSmall) ??
            const TextStyle(fontSize: AppSizes.fontSmall);
      case ButtonSize.medium:
        return baseStyle?.copyWith(fontSize: AppSizes.fontMedium) ??
            const TextStyle(fontSize: AppSizes.fontMedium);
      case ButtonSize.large:
        return baseStyle?.copyWith(fontSize: AppSizes.fontLarge) ??
            const TextStyle(fontSize: AppSizes.fontLarge);
    }
  }

  String _getLoadingText() {
    return 'Yükleniyor...';
  }
}

/// Buton türleri
enum ButtonType { primary, secondary, text, danger, success }

/// Buton boyutları
enum ButtonSize { small, medium, large }
