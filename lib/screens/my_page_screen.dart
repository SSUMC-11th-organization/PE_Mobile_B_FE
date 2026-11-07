import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/stat_item.dart';

// 마이페이지 탭 — 닉네임/이메일은 AuthViewModel.member(GET /v7/members/me)에서 표시
// 사진·소개·통계·장르는 기존 프로필 디자인(profile_screen.dart)의 정적 요소 그대로
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;

    return Scaffold(
      appBar: CommonAppBar(
        title: '마이페이지',
        actions: [
          // 로그아웃 → signedOut이 되면 GoRouter redirect가 /login으로 이동
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: auth.logout,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.white,
                backgroundImage: AssetImage('assets/images/profile.png'),
              ),
            ),
            const SizedBox(height: 16),
            _MemberHeader(auth: auth),
            const SizedBox(height: 8),
            const Text(
              '매주 주말엔 영화관으로 출근하는 프로 관람객. 좋은 영화를 보고 기록하는 것을 좋아합니다.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton(
                // 내 정보를 불러오기 전에는 수정 화면에 들어갈 수 없음
                onPressed: member == null
                    ? null
                    : () => context.push('/my/profile/edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.violet,
                  side: const BorderSide(color: AppColors.violet),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
                child: const Text('프로필 수정'),
              ),
            ),
            const SizedBox(height: 24),
            const Row(
              children: [
                StatItem(label: '본 영화', value: '342'),
                StatItem(label: '평점', value: '4.2'),
                StatItem(label: '즐겨찾기', value: '58'),
              ],
            ),
            const SizedBox(height: 24),
            const Text('선호하는 장르', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('드라마')),
                Chip(label: Text('SF')),
                Chip(label: Text('애니메이션')),
              ],
            ),
            const SizedBox(height: 16),
            // 이번 세션 평점 + 학습용 공개 조회 — push로 탭 위에 쌓음 ("내 평점 전체"가 아님)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('평점 기록'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/my/ratings'),
            ),
          ],
        ),
      ),
    );
  }
}

// 닉네임 + 이메일 — 조회 상태에 따라 로딩/오류(다시 시도)/값 표시
class _MemberHeader extends StatelessWidget {
  const _MemberHeader({required this.auth});

  final AuthViewModel auth;

  @override
  Widget build(BuildContext context) {
    final member = auth.member;
    if (member != null) {
      return Column(
        children: [
          Text(
            member.nickname,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            member.email,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
        ],
      );
    }
    if (auth.memberLoadStatus == MemberLoadStatus.error) {
      return Column(
        children: [
          Text(
            auth.memberErrorMessage ?? '내 정보를 불러오지 못했습니다.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
          TextButton(
            onPressed: auth.loadMember,
            child: const Text('다시 시도'),
          ),
        ],
      );
    }
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
