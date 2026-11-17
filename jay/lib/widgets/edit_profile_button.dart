import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key, required this.onPressed});

  /// member가 없을 때는 null을 넘겨 버튼을 비활성화합니다.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.violet,
        elevation: 0,
        side: const BorderSide(color: AppColors.violet),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('프로필 수정'),
    );
  }
}
