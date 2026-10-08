import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 1. 로딩 상태 화면 (Loading)
/// 데이터를 불러오는 동안 빙글빙글 도는 인디케이터를 표시합니다.
class MovieListLoading extends StatelessWidget {
  const MovieListLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.violet,
      ),
    );
  }
}

/// 2. 빈 데이터 상태 화면 (Empty)
/// 데이터는 성공적으로 불러왔지만, 표시할 영화가 없을 때 보여주는 화면입니다.
class MovieListEmpty extends StatelessWidget {
  const MovieListEmpty({
    super.key,
    this.message = '조건에 맞는 영화가 없습니다.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.movie_outlined,
            size: 48,
            color: AppColors.gray,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.gray),
          ),
        ],
      ),
    );
  }
}

/// 3. 오류 상태 화면 (Error)
/// 네트워크 오류나 예외가 발생했을 때 사용자에게 안내하고 '다시 시도' 버튼을 제공합니다.
class MovieListError extends StatelessWidget {
  const MovieListError({
    super.key,
    required this.onRetry,
    this.message = '영화를 불러오지 못했습니다.',
  });

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.violet,
              foregroundColor: AppColors.white,
            ),
            onPressed: onRetry,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
