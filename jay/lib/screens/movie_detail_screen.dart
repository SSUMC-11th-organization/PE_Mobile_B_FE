import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:jay/view_models/movie_detail_view_model.dart';
import 'package:jay/view_models/signup_view_model.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/movie_format.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});
  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool isFavorite = false;

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
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingDialog(
        onSubmit: (score, comment) async {
          final viewModel = context.read<MovieDetailViewModel>();
          await viewModel.createRating(score: score, comment: comment);
          if (viewModel.submitStatus != SubmitStatus.success) {
            throw StateError(viewModel.submitMessage ?? '저장에 실패했습니다.');
          }
        },
      ),
    );
    if (!mounted || saved != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MovieDetailViewModel>();
    final movie = viewModel.movie;

    return Scaffold(
      appBar: CommonAppBar(
        title: 'Cinema Archive',
        centerTitle: true,
        titleStyle: AppTextStyles.titleMedium.copyWith(color: AppColors.violet),
        onBack: () => context.pop(),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.share))],
      ),
      // movie는 MovieDetailLoader가 불러온 값이라 null이 아닙니다.
      body: SingleChildScrollView(
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
                        fiveStarRating(movie.voteAverage).toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
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
      bottomNavigationBar: SafeArea(
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
                  // 학습용 회원가입 전(memberId 없음)에는 등록 버튼을 비활성화합니다.
                  onPressed: viewModel.memberId == null
                      ? null
                      : _openRatingDialog,
                  icon: const Icon(Icons.rate_review),
                  label: Text(
                    viewModel.memberId == null ? '회원가입 후 평점 남기기' : '평점 남기기',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
