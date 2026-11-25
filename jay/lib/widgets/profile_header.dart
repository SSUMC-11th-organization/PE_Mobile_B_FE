import 'package:flutter/material.dart';
import 'package:jay/data/models/member_info.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// GET /v8/members/me 응답(이메일·닉네임·가입일)을 표시합니다.
/// 사진은 기존 디자인 예시 이미지입니다.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.member});

  final MemberInfo member;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/profile/profile_movielog.jpg',
            width: 88,
            height: 88,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 16),
        Text(member.nickname, style: AppTextStyles.titleLarge),
        const SizedBox(height: 4),
        // Challenge: 닉네임 아래 가입일 표시
        Text(
          formatJoinedDate(member.createdAt),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray),
        ),
        const SizedBox(height: 4),
        Text(member.email, style: AppTextStyles.bodySmall),
      ],
    );
  }
}
