import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId, this.movie});

  final int movieId;
  final TmdbMovieDto? movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  double _myRating = 0;
  bool _isFavorite = false;

  Future<void> _openRatingDialog(TmdbMovieDto movie) async {
    final rating = await showDialog<double>(
      context: context,
      builder: (context) => RatingDialog(initialRating: _myRating),
    );
    if (rating == null || !mounted) return;
    setState(() => _myRating = rating);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$rating점을 남겼어요.')));
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isFavorite ? '즐겨찾기에 추가했어요.' : '즐겨찾기에서 삭제했어요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;

    if (movie == null) {
      return Scaffold(
        appBar: CommonAppBar(title: '영화 상세', onBack: () => context.pop()),
        body: const Center(child: Text('영화를 찾을 수 없어요.')),
      );
    }

    final year = movie.releaseDate?.isNotEmpty == true
        ? movie.releaseDate!.substring(0, 4)
        : '연도 미정';

    return Scaffold(
      appBar: CommonAppBar(
        title: movie.title,
        onBack: () => context.pop(),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: AppColors.violet,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      backgroundColor: AppColors.warmWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TmdbPosterImage(
                posterPath: movie.posterPath,
                width: double.infinity,
                height: 260,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(height: 20),
              Text(movie.title, style: AppTextStyles.titleLarge),
              const SizedBox(height: 6),
              Text(year, style: AppTextStyles.bodySmall),
              const SizedBox(height: 16),
              Row(
                children: [
                  RatingBarIndicator(
                    rating: movie.voteAverage / 2,
                    itemCount: 5,
                    itemSize: 22,
                    itemBuilder: (context, _) =>
                        const Icon(Icons.star, color: AppColors.violet),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${movie.voteAverage}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
              if (movie.overview.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(movie.overview, style: AppTextStyles.bodyMedium),
              ],
              const SizedBox(height: 24),
              if (_myRating > 0) ...[
                Text('내가 남긴 평점', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                RatingBarIndicator(
                  rating: _myRating,
                  itemCount: 5,
                  itemSize: 22,
                  itemBuilder: (context, _) =>
                      const Icon(Icons.star, color: AppColors.violet),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _openRatingDialog(movie),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_myRating > 0 ? '평점 다시 남기기' : '평점 남기기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
