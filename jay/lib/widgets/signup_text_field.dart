import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SignUpTextField extends StatefulWidget {
  const SignUpTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.validator,
    this.errorText,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;

  /// 서버 중복 확인 등 validator 밖에서 결정되는 에러 문구입니다.
  final String? errorText;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<SignUpTextField> createState() => _SignUpTextFieldState();
}

class _SignUpTextFieldState extends State<SignUpTextField> {
  bool _interacted = false;

  Widget? _buildStatusIcon() {
    if (!_interacted) return null;

    final hasError =
        widget.errorText != null ||
        widget.validator(widget.controller.text) != null;
    return hasError
        ? const Icon(Icons.error_outline, color: AppColors.error)
        : const Icon(Icons.check_circle, color: AppColors.violet);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: widget.obscureText,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: widget.hintText,
            errorText: widget.errorText,
            suffixIcon: _buildStatusIcon(),
          ),
          validator: widget.validator,
          onChanged: (value) {
            setState(() => _interacted = true);
            widget.onChanged?.call(value);
          },
          onFieldSubmitted: widget.onFieldSubmitted,
        ),
      ],
    );
  }
}
