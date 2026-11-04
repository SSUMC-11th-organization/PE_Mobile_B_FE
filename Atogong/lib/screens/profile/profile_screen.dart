import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/common_app_bar.dart';
import 'widgets/edit_profile_button.dart';
import 'widgets/favorite_genres.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_stats.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: '내 프로필'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ProfileHeader(
                imagePath: 'assets/images/profile/profile_movielog.jpg',
              ),
              const SizedBox(height: 24),
              const EditProfileButton(),
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
