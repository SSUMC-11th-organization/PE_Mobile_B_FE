import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/movie_detail_view_model.dart';
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
  bool _isFavorite = false;

  Future<void> _openRatingDialog() async {
    final viewModel = context.read<MovieDetailViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막습니다.
      builder: (_) => RatingDialog(
        onSubmit: (score, comment) async {
          await viewModel.createRating(score: score, comment: comment);
          if (viewModel.submitStatus != SubmitStatus.success) {
            throw StateError(viewModel.submitMessage ?? '저장에 실패했습니다.');
          }
        },
      ),
    );
    if (!mounted || saved != true) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.'),
      ),
    );
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
    final hasMember = context.read<MovieDetailViewModel>().memberId != null;

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
              if (!hasMember) ...[
                const Text(
                  '평점을 남기려면 먼저 학습용 회원가입을 완료해 주세요.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: hasMember ? _openRatingDialog : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('평점 남기기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
