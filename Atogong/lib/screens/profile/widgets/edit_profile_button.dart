import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key, this.onPressed});

  /// null이면 비활성. 내 정보(member)를 받은 뒤에만 켜짐
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.violet,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          side: const BorderSide(color: AppColors.violet, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          '프로필 수정',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.violet),
        ),
      ),
    );
  }
}
