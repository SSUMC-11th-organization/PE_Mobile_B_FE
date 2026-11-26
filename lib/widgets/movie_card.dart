import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_text_styles.dart';
import 'tmdb_poster_image.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie, this.onTap});

  final TmdbMovieDto movie;

  /// 없으면 상세로 push합니다. 복귀 후 갱신이 필요한 화면만 지정합니다.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final year = movie.releaseDate?.isNotEmpty == true
        ? movie.releaseDate!.substring(0, 4)
        : '연도 미정';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () => context.push('/movies/${movie.id}', extra: movie),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TmdbPosterImage(
              posterPath: movie.posterPath,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(year, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
