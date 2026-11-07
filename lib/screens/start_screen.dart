import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/auth_view_model.dart';
import '../widgets/movielog_button.dart';

// Splash(/start) — 앱 시작 시 세션 확인 중(initializing)이거나, 확인에 실패해 재시도가 필요할 때(retryRequired) 표시
// 화면 이동은 GoRouter redirect가 AuthStatus를 보고 처리 (여기서 직접 go 하지 않음)
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final needsRetry = auth.status == AuthStatus.retryRequired;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.movie_outlined,
                size: 72,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 24),
              const Text(
                '영화의 순간을 기록하세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              if (needsRetry) ...[
                Text(
                  auth.sessionErrorMessage ?? '로그인 상태를 확인하지 못했습니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                MovieLogButton(
                  label: '다시 시도',
                  width: double.infinity,
                  onPressed: auth.restoreSession,
                ),
              ] else
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
