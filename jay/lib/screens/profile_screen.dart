import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jay/view_models/auth_view_model.dart';
import 'package:jay/widgets/common_app_bar.dart';
import 'package:jay/widgets/edit_profile_button.dart';
import 'package:jay/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../widgets/favorite_genres.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // watch로 구독해야 프로필 수정 후 member가 바뀌면 다시 그려집니다.
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;

    return Scaffold(
      appBar: CommonAppBar(
        title: '내 프로필',
        actions: [
          // Required: 로그아웃 → 토큰·member 삭제 → signedOut → Router가 /login으로 이동
          TextButton(
            onPressed: auth.storageCleanUpInProgress ? null : auth.logout,
            style: TextButton.styleFrom(foregroundColor: AppColors.violet),
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: SafeArea(
        child: member == null
            ? _MemberLoadState(
                // Challenge: MainScreen이 시작한 로딩 상태를 구독해 로딩·실패·재시도 표시
                failed: auth.memberStatus == MemberLoadStatus.error,
                onRetry: () => auth.loadMember(force: true),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ProfileHeader(member: member),
                    const SizedBox(height: 24),
                    EditProfileButton(
                      onPressed: () => context.push('/my/profile/edit'),
                    ),
                    // 통계·장르는 기존 디자인 예시입니다. (v7 GET me 응답에 없음)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 24),
                      child: const ProfileStats(),
                    ),
                    ListTile(
                      title: const Text('내가 등록한 평점'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/my/ratings'),
                    ),
                    ListTile(
                      title: const Text('내 즐겨찾기'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/my/favorites'),
                    ),
                    const SizedBox(height: 24),
                    const FavoriteGenres(),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MemberLoadState extends StatelessWidget {
  const _MemberLoadState({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!failed) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('내 정보를 불러오지 못했어요.'),
            const SizedBox(height: 16),
            MovieLogButton(label: '다시 시도', width: 180, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
