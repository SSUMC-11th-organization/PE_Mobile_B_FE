import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, this.imagePath, this.nickname, this.email});
  final String? imagePath;
  final String? nickname; // 8주차: GET /v8/members/me로 받은 값. 아직 못 받았으면 null
  final String? email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center, // Column의 교차축(가로) 가운데
      children: [
        // 원형 프로필 사진 (Image.asset 대신 CircleAvatar.backgroundImage 사용)
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.violet, width: 2),
          ),
          child: imagePath == null
              ? const CircleAvatar(
                  radius: 64,
                  backgroundColor: AppColors.lavender,
                  child: Icon(Icons.person, size: 56, color: AppColors.violet),
                )
              : ClipOval(
                  child: Image.asset(
                    imagePath!,
                    width: 128,
                    height: 128,
                    fit: BoxFit.cover,
                  ),
                ),
        ),
        const SizedBox(height: 16),

        // SVG 아이콘 + 닉네임
        Row(
          mainAxisAlignment: MainAxisAlignment.center, // Row의 주축(가로) 가운데
          crossAxisAlignment: CrossAxisAlignment.center, // 교차축(세로) 가운데
          children: [
            SvgPicture.asset(
              'assets/icons/movie.svg', // ← assets/icons 안 실제 파일명으로
              width: 22,
              height: 22,
              semanticsLabel: '영화 아이콘',
              colorFilter: const ColorFilter.mode(
                AppColors.violet,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              nickname ?? '불러오는 중…',
              style: AppTextStyles.titleLarge.copyWith(fontSize: 28),
            ),
          ],
        ),
        if (email != null) ...[
          const SizedBox(height: 4),
          Text(
            email!,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.gray),
          ),
        ],
        const SizedBox(height: 8),

        // 소개
        Text(
          '매주 주말엔 영화관으로 출근하는 프로 관람객. 좋은 영화를 보고 기록하는 것을 좋아합니다.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.gray),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
