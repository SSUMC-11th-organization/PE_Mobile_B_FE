import 'package:flutter/material.dart';

import '../../widgets/common_app_bar.dart';
import 'widgets/edit_profile_button.dart';
import 'widgets/favorite_genres.dart';
import 'widgets/my_ratings.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_stats.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CommonAppBar(title: '내 프로필'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileHeader(
                imagePath: 'assets/images/profile/profile_movielog.jpg',
              ),
              SizedBox(height: 24),
              EditProfileButton(),
              SizedBox(height: 32),
              ProfileStats(),
              SizedBox(height: 32),
              FavoriteGenres(),
              SizedBox(height: 32),
              MyRatings(),
            ],
          ),
        ),
      ),
    );
  }
}
