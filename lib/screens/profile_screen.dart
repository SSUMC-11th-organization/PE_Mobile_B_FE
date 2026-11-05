import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/rating_dto.dart';
import '../data/services/rating_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/stat_item.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<RatingDto>? _ratings;
  static const int _testMemberId = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRatings();
    });
  }

  Future<void> _loadRatings() async {
    try {
      final service = context.read<RatingApiService>();
      final list = await service.fetchMyRatings(_testMemberId);
      if (mounted) {
        setState(() {
          _ratings = list;
        });
      }
    } catch (_) {
      // 오류 발생 시 기존 상태 유지
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratingCount = _ratings != null ? _ratings!.length.toString() : '3';

    return Scaffold(
      appBar: const CommonAppBar(title: '마이페이지', centerTitle: true),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRatings,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ProfileHeader(),
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
                          '내가 남긴 별점과 감상평 확인하기',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.gray,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.gray,
                        ),
                        onTap: () async {
                          await context.push('/my/ratings');
                          _loadRatings();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                const EditProfileButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 44,
          backgroundImage: AssetImage('assets/images/profile.png'),
        ),
        const SizedBox(height: 12),
        Text('무비러버', style: AppTextStyles.titleLarge),
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
    return ElevatedButton(
      onPressed: () {},
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
