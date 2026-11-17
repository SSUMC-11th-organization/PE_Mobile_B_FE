import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import 'temp_login_dialog.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Text(
                'FLUTTER 3주차',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: AppColors.gray,
                ),
              ),
              const SizedBox(height: 100),
              SvgPicture.asset(
                'assets/logos/movielog_logo.svg',
                width: 80,
                height: 80,
                semanticsLabel: 'MovieLog 로고',
              ),
              const SizedBox(height: 60),
              const Text(
                '영화의 순간을\n기록하세요',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              const Text(
                '보고 싶은 영화부터 나만의 평점까지\n한곳에서 관리해요',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.gray,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => context.go('/register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('시작하기', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => showTempLoginDialog(context),
                child: const Text('임시 로그인 (memberId)'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
