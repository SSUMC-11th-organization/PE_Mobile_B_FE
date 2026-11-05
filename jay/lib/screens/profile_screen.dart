import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jay/widgets/common_app_bar.dart';
import 'package:jay/widgets/edit_profile_button.dart';

import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart';
import '../widgets/favorite_genres.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: CommonAppBar(title: '내 프로필'),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ProfileHeader(),
                SizedBox(height: 24),
                EditProfileButton(),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 24),
                  child: const ProfileStats(),
                ),
                ListTile(
                  title: const Text('내가 등록한 평점'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/my/ratings'),
                ),
                const SizedBox(height: 24),
                const FavoriteGenres(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
