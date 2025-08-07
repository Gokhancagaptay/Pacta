// lib/widgets/common/custom_text_field.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pacta/constants/app_constants.dart';
import 'package:pacta/utils/validation_utils.dart';

/// Özelleştirilebilir text field widget'ı
class CustomTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final Widget? suffix;
  final VoidCallback? onTap;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;

  const CustomTextField({
    super.key,
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffix,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
  });

  /// Email input field
  const CustomTextField.email({
    super.key,
    this.label = AppConstants.emailLabel,
    this.hint = 'ornek@email.com',
    this.errorText,
    this.controller,
    this.validator = ValidationUtils.validateEmail,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  }) : keyboardType = TextInputType.emailAddress,
       textInputAction = TextInputAction.next,
       obscureText = false,
       readOnly = false,
       maxLines = 1,
       maxLength = null,
       prefixIcon = Icons.email,
       suffix = null,
       onTap = null,
       inputFormatters = null,
       textCapitalization = TextCapitalization.none;

  /// Password input field
  const CustomTextField.password({
    super.key,
    this.label = AppConstants.passwordLabel,
    this.hint = 'Şifrenizi girin',
    this.errorText,
    this.controller,
    this.validator = ValidationUtils.validatePassword,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  }) : keyboardType = TextInputType.visiblePassword,
       textInputAction = TextInputAction.done,
       obscureText = true,
       readOnly = false,
       maxLines = 1,
       maxLength = null,
       prefixIcon = Icons.lock,
       suffix = null,
       onTap = null,
       inputFormatters = null,
       textCapitalization = TextCapitalization.none;

  /// Name input field
  const CustomTextField.name({
    super.key,
    this.label = AppConstants.nameLabel,
    this.hint = 'Ad ve soyadınızı girin',
    this.errorText,
    this.controller,
    this.validator = ValidationUtils.validateName,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  }) : keyboardType = TextInputType.name,
       textInputAction = TextInputAction.next,
       obscureText = false,
       readOnly = false,
       maxLines = 1,
       maxLength = AppConstants.maxUsernameLength,
       prefixIcon = Icons.person,
       suffix = null,
       onTap = null,
       inputFormatters = null,
       textCapitalization = TextCapitalization.words;

  /// Phone input field
  const CustomTextField.phone({
    super.key,
    this.label = AppConstants.phoneLabel,
    this.hint = '05XX XXX XX XX',
    this.errorText,
    this.controller,
    this.validator = ValidationUtils.validatePhone,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  }) : keyboardType = TextInputType.phone,
       textInputAction = TextInputAction.next,
       obscureText = false,
       readOnly = false,
       maxLines = 1,
       maxLength = 11,
       prefixIcon = Icons.phone,
       suffix = null,
       onTap = null,
       inputFormatters = null,
       textCapitalization = TextCapitalization.none;

  /// Amount input field
  const CustomTextField.amount({
    super.key,
    this.label = AppConstants.amountLabel,
    this.hint = '0.00',
    this.errorText,
    this.controller,
    this.validator = ValidationUtils.validateAmount,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  }) : keyboardType = const TextInputType.numberWithOptions(decimal: true),
       textInputAction = TextInputAction.next,
       obscureText = false,
       readOnly = false,
       maxLines = 1,
       maxLength = null,
       prefixIcon = Icons.attach_money,
       suffix = null,
       onTap = null,
       inputFormatters = null,
       textCapitalization = TextCapitalization.none;

  /// Search input field
  const CustomTextField.search({
    super.key,
    this.label,
    this.hint = 'Arama yapın...',
    this.errorText,
    this.controller,
    this.validator,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.suffix,
  }) : keyboardType = TextInputType.text,
       textInputAction = TextInputAction.search,
       obscureText = false,
       readOnly = false,
       maxLines = 1,
       maxLength = null,
       prefixIcon = Icons.search,
       onTap = null,
       inputFormatters = null,
       textCapitalization = TextCapitalization.none;

  /// Multiline text area
  const CustomTextField.multiline({
    super.key,
    this.label = AppConstants.descriptionLabel,
    this.hint = 'Açıklama girin...',
    this.errorText,
    this.controller,
    this.validator = ValidationUtils.validateDescription,
    this.enabled = true,
    this.maxLines = 4,
    this.maxLength = 500,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  }) : keyboardType = TextInputType.multiline,
       textInputAction = TextInputAction.newline,
       obscureText = false,
       readOnly = false,
       prefixIcon = null,
       suffix = null,
       onTap = null,
       inputFormatters = null,
       textCapitalization = TextCapitalization.sentences;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: AppConstants.smallPadding),
        ],
        TextFormField(
          controller: widget.controller,
          validator: _validateInput,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: _obscureText,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          focusNode: widget.focusNode,
          textCapitalization: widget.textCapitalization,
          inputFormatters: widget.inputFormatters,
          onTap: widget.onTap,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: _showError ? widget.errorText : null,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon)
                : null,
            suffixIcon: _buildSuffixIcon(),
            counterText: widget.maxLength != null ? null : '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.defaultBorderRadius,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.defaultBorderRadius,
              ),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.defaultBorderRadius,
              ),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.defaultBorderRadius,
              ),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.defaultBorderRadius,
              ),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.defaultPadding,
              vertical: AppConstants.smallPadding,
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.suffix != null) {
      return widget.suffix;
    }

    if (widget.obscureText) {
      return IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility : Icons.visibility_off,
          color: Colors.grey,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }

    return null;
  }

  String? _validateInput(String? value) {
    if (widget.validator != null) {
      final error = widget.validator!(value);
      setState(() {
        _showError = error != null;
      });
      return error;
    }
    return null;
  }
}
