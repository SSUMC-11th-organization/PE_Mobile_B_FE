import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../widgets/movielog_button.dart';

/// 스플래시 겸용 시작 화면. 
/// onRetry가 없으면 세션 확인 중(initializing), 있으면 확인 실패(retryRequired)입니다.
/// 화면 이동은 하지 않습니다. Router가 인증 상태를 보고 결정합니다.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

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
                'FLUTTER 8주차',
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
              if (onRetry == null)
                const CircularProgressIndicator(color: AppColors.violet)
              else
                Column(
                  children: [
                    Text(
                      message ?? '로그인 상태를 확인하지 못했어요.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    MovieLogButton(
                      label: '다시 시도',
                      width: double.infinity,
                      onPressed: onRetry,
                    ),
                  ],
                ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
