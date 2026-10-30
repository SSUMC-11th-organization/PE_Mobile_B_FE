import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/movie_format.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId, this.movie});

  // TMDB 영화 id → 이후 평점 저장 시 CreateRatingRequest.movieId로 사용
  final int movieId;
  // 목록에서 go_router extra로 전달받은 영화 정보
  final TmdbMovieDto? movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool isFavorite = false;
  double? myRating;

  void _toggleFavorite() {
    setState(() {
      isFavorite = !isFavorite;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _openRatingDialog() async {
    final rating = await showDialog<double>(
      context: context,
      builder: (context) => const RatingDialog(),
    );
    if (rating == null || !mounted) return;

    // TODO(평점 API): widget.movieId(TMDB id)를 movieId로 담아 자체 백엔드에 저장
    setState(() {
      myRating = rating;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$rating점으로 평가했습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;

    return Scaffold(
      appBar: CommonAppBar(
        title: 'Cinema Archive',
        centerTitle: true,
        titleStyle: AppTextStyles.titleMedium.copyWith(color: AppColors.violet),
        onBack: () => context.pop(),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.share))],
      ),
      body: movie == null
          ? const Center(child: Text('영화를 찾을 수 없어요.'))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TmdbPosterImage(
                    posterPath: movie.posterPath,
                    width: double.infinity,
                    height: 320,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(movie.title, style: AppTextStyles.titleLarge),
                        // release_date가 없으면 연도를 표시하지 않는다
                        if (releaseYear(movie.releaseDate) case final year?) ...[
                          const SizedBox(height: 4),
                          Text(year, style: AppTextStyles.bodySmall),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            RatingBarIndicator(
                              rating: fiveStarRating(movie.voteAverage),
                              itemCount: 5,
                              itemSize: 20,
                              itemBuilder: (context, index) =>
                                  const Icon(Icons.star, color: AppColors.violet),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              fiveStarRating(
                                movie.voteAverage,
                              ).toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (myRating != null) ...[
                              const SizedBox(width: 12),
                              Text(
                                '내 평점 $myRating',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ],
                        ),
                        const Divider(height: 32),
                        const Text('시놉시스', style: AppTextStyles.titleMedium),
                        const SizedBox(height: 8),
                        if (movie.overview.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                '줄거리 정보가 없어요.',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                          )
                        else
                          Text(movie.overview, style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: movie == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _toggleFavorite,
                        icon: Icon(
                          isFavorite ? Icons.bookmark : Icons.bookmark_border,
                        ),
                        label: const Text('즐겨찾기'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _openRatingDialog,
                        icon: const Icon(Icons.rate_review),
                        label: const Text('평점 남기기'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
