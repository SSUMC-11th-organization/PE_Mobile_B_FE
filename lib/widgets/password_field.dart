import 'package:flutter/material.dart';

class PasswordField extends StatelessWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String? errorText; // 서버가 알려준 비밀번호 오류 (클라이언트 validator와 별개)

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(labelText: '비밀번호', errorText: errorText),
      obscureText: true,
      textInputAction: TextInputAction.done,
      validator: (value) {
        final password = value ?? '';
        if (password.isEmpty) {
          return '비밀번호를 입력해주세요.';
        }
        if (password.length < 8) {
          return '비밀번호는 8자 이상 입력해주세요.';
        }
        return null;
      },
      onChanged: onChanged,
      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
    );
  }
}
