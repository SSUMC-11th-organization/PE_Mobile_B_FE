import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../view_models/auth_view_model.dart';
import '../../widgets/common_app_bar.dart';
import 'widgets/edit_profile_button.dart';
import 'widgets/favorite_genres.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_stats.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // read가 아니라 watch로 구독해야 내 정보 로딩·닉네임 수정이 끝났을 때 다시 그려짐
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;

    return Scaffold(
      appBar: CommonAppBar(
        title: '내 프로필',
        actions: [
          // 토큰과 member를 지우고 signedOut으로 바꾸면 Router가 /login으로 보냄 (직접 이동하지 않음)
          TextButton(
            onPressed: auth.storageCleanupInProgress ? null : auth.logout,
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 사진·소개·통계·장르는 기존 디자인 예시. 서버가 주는 내 정보는 이메일·닉네임·가입일뿐
              ProfileHeader(
                imagePath: 'assets/images/profile/profile_movielog.jpg',
                nickname: member?.nickname,
                email: member?.email,
              ),
              // 네트워크 실패는 로그아웃하지 않고 다시 불러올 수 있게 함
              if (auth.memberStatus == MemberLoadStatus.error)
                Center(
                  child: TextButton(
                    onPressed: () => auth.loadMember(force: true),
                    child: const Text('내 정보를 불러오지 못했어요. 다시 시도'),
                  ),
                ),
              const SizedBox(height: 24),
              EditProfileButton(
                onPressed: member == null
                    ? null
                    : () => context.push('/my/profile/edit'),
              ),
              const SizedBox(height: 32),
              const ProfileStats(),
              const SizedBox(height: 32),
              const FavoriteGenres(),
              const SizedBox(height: 32),
              // 자식 화면으로 push. 뒤로가면 마이페이지로 복귀
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('내가 등록한 평점'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/my/ratings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
