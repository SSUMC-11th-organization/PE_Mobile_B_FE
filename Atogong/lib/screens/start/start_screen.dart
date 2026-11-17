import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../widgets/movielog_button.dart';

/// 8주차: 1주차 시작 화면의 레이아웃을 그대로 재사용한 스플래시.
/// 저장된 토큰을 확인하는 동안 빈 화면이나 로그인·홈이 잠깐 보이지 않게 이 화면을 유지.
/// onRetry가 없으면 확인 중(initializing), 있으면 확인 실패(retryRequired)
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 50),

              const Text(
                "Flutter 8주차",
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, letterSpacing: 1.5),
              ),

              const SizedBox(height: 60),

              SvgPicture.asset(
                'assets/logos/movielog_logo.svg',
                width: 72,
                height: 72,
                semanticsLabel: 'MovieLog 로고',
              ),

              const SizedBox(height: 60),

              const Text(
                "영화의 순간을\n기록하세요",
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                "보고 싶은 영화부터 나만의 평점까지\n한 곳에서 관리해요",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),

              const Spacer(),

              // 1주차의 '시작하기' 버튼 자리를 로딩 / 재시도 상태로 대체
              if (onRetry == null)
                const CircularProgressIndicator()
              else ...[
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
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
