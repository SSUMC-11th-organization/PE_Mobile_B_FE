import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_text_styles.dart';
import 'tmdb_poster_image.dart';

// TMDB 영화 카드 (홈 전용) — 4주차 MovieCard(Movie 모델, 목록 화면에서 사용)는 그대로 둠
class TmdbMovieCard extends StatelessWidget {
  const TmdbMovieCard({super.key, required this.movie});

  final TmdbMovieDto movie;

  @override
  Widget build(BuildContext context) {
    final year = movie.releaseYear;

    return GestureDetector(
      // 상세 화면은 아직 mockMovies 기준이라 TMDB id는 "찾을 수 없음"으로 표시됨 (상세 연동 단계에서 수정)
      onTap: () => context.push('/movies/${movie.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expanded = 제목/부가 정보를 뺀 나머지 높이를 포스터가 채움 → 그리드 칸·가로 목록 높이에 맞춰짐
          Expanded(child: TmdbPosterImage(posterPath: movie.posterPath)),
          const SizedBox(height: 8),
          Text(
            movie.title,
            style: AppTextStyles.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // 제목이 길면 … 처리
          ),
          const SizedBox(height: 4),
          // TMDB 목록 응답에는 장르 이름이 없어(genre_ids만 있음) 개봉 연도·평점을 표시
          Text(
            [
              if (year != null) '$year',
              '★ ${movie.voteAverage.toStringAsFixed(1)}',
            ].join(' · '),
            style: AppTextStyles.bodySmall,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
