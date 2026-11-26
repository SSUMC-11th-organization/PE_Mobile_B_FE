import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/stat_item.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // read가 아니라 select로 구독해야 닉네임·개수가 바뀔 때 다시 그려집니다.
    final nickname =
        context.select<AuthViewModel, String?>((a) => a.member?.nickname);
    // 이번 로그인 세션에서 등록한 평점 개수 (v7에는 내 평점 전체 조회 API가 없음)
    final ratingCount = context
        .select<MyRatingsViewModel, int>((m) => m.ratings.length)
        .toString();

    return Scaffold(
      appBar: CommonAppBar(
        title: '마이페이지',
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout, color: AppColors.violet),
            // 이동은 호출하지 않습니다. signedOut이 되면 Router가 /login으로 보냅니다.
            onPressed: () => context.read<AuthViewModel>().logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileHeader(nickname: nickname ?? '불러오는 중…'),
              const SizedBox(height: 28),
              ProfileStats(ratingCount: ratingCount),
              const SizedBox(height: 28),
              const FavoriteGenres(),
              const SizedBox(height: 28),

              // 6주차 마이페이지 진입 항목: 내가 등록한 평점
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightGray),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                // ListTile의 배경·잉크가 흰 DecoratedBox에 가려지지 않도록 Material로 감쌉니다.
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.lightViolet,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: AppColors.violet,
                            size: 22,
                          ),
                        ),
                        title: const Text(
                          '내가 등록한 평점',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                          ),
                        ),
                        subtitle: const Text(
                          '이번 로그인에서 남긴 별점과 감상평 확인하기',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.gray,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.gray,
                        ),
                        onTap: () => context.push('/my/ratings'),
                      ),
                      const Divider(height: 1, color: AppColors.lightGray),
                      ListTile(
                        // 내 정보가 준비된 뒤에만 활성화합니다.
                        enabled: nickname != null,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.lightViolet,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.bookmark_rounded,
                            color: AppColors.violet,
                            size: 22,
                          ),
                        ),
                        title: const Text(
                          '내 즐겨찾기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.gray,
                        ),
                        onTap: () => context.push('/my/favorites'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              const EditProfileButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.nickname});

  final String nickname;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 44,
          backgroundImage: AssetImage('assets/images/profile.png'),
        ),
        const SizedBox(height: 12),
        Text(nickname, style: AppTextStyles.titleLarge),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/movie.svg',
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(
                AppColors.violet,
                BlendMode.srcIn,
              ),
              semanticsLabel: '영화 아이콘',
            ),
            const SizedBox(width: 6),
            Text('좋아하는 영화를 기록하고 있어요', style: AppTextStyles.bodySmall),
          ],
        ),
      ],
    );
  }
}

class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key, required this.ratingCount});

  final String ratingCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: StatItem(label: '본 영화', value: '24'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatItem(label: '평점', value: ratingCount),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: StatItem(label: '즐겨찾기', value: '7'),
        ),
      ],
    );
  }
}

class FavoriteGenres extends StatelessWidget {
  const FavoriteGenres({super.key});

  static const _genres = ['드라마', 'SF', '애니메이션'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('선호 장르', style: AppTextStyles.titleMedium),
        Container(
          margin: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final genre in _genres)
                Chip(
                  label: Text(genre),
                  backgroundColor: AppColors.warmWhite,
                  side: const BorderSide(color: AppColors.violet),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    // 내 정보를 불러온 뒤에만 활성화합니다(현재 닉네임이 있어야 수정 가능).
    final ready = context.select<AuthViewModel, bool>((a) => a.member != null);
    return ElevatedButton(
      onPressed: ready ? () => context.push('/my/profile/edit') : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.violet,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('프로필 수정'),
    );
  }
}
