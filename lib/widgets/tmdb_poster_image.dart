import 'package:flutter/material.dart';

import '../core/config/tmdb_config.dart';
import '../theme/app_colors.dart';

// TMDB 포스터 이미지 — posterPath가 없거나 이미지 로드에 실패하면 placeholder 아이콘 표시
class TmdbPosterImage extends StatelessWidget {
  const TmdbPosterImage({
    super.key,
    required this.posterPath,
    this.borderRadius = 8,
  });

  final String? posterPath; // 예: /abc.jpg
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = TmdbConfig.posterUrl(posterPath); // null/빈 값이면 null

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox.expand(
        child: url == null
            ? const _PosterPlaceholder()
            : Image.network(
                url,
                fit: BoxFit.cover,
                // 다운로드 중에는 placeholder 위에 작은 로딩 표시
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const _PosterPlaceholder(loading: true);
                },
                // 404·네트워크 오류 등으로 이미지를 못 불러오면 placeholder로 대체
                errorBuilder: (context, error, stackTrace) =>
                    const _PosterPlaceholder(),
              ),
      ),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.gray.withValues(alpha: 0.3),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.movie_outlined, color: AppColors.gray, size: 32),
      ),
    );
  }
}
