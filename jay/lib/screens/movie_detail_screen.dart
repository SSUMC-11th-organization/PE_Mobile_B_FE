import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:jay/view_models/movie_detail_view_model.dart';
import 'package:jay/view_models/signup_view_model.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/movie_format.dart';
import '../view_models/favorite_detail_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/favorite_button.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});
  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoriteDetailViewModel>().load();
    });
  }

  /// 등록(myRating == null)과 수정(myRating != null)을 같은 Dialog로 처리합니다.
  /// 수정 시에는 기존 score·comment를 채워 PATCH 전체 교체로 comment가 지워지지 않게 합니다.
  Future<void> _openRatingDialog() async {
    final viewModel = context.read<MovieDetailViewModel>();
    final existing = viewModel.myRating;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingDialog(
        initialScore: existing?.score ?? 0,
        initialComment: existing?.comment,
        onSubmit: (score, comment) async {
          if (existing == null) {
            await viewModel.createRating(score: score, comment: comment);
          } else {
            await viewModel.updateRating(score: score, comment: comment);
          }
          if (viewModel.submitStatus != SubmitStatus.success) {
            throw StateError(viewModel.submitMessage ?? '저장에 실패했습니다.');
          }
        },
      ),
    );
    if (!mounted || saved != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(existing == null ? '평점을 등록했습니다.' : '평점을 수정했습니다.')),
    );
  }

  Future<void> _confirmDelete() async {
    final viewModel = context.read<MovieDetailViewModel>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('평점을 삭제할까요?'),
        content: const Text('삭제한 평점은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await viewModel.deleteRating();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          viewModel.submitStatus == SubmitStatus.success
              ? '평점을 삭제했습니다.'
              : viewModel.submitMessage ?? '삭제하지 못했습니다.',
        ),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(movie.title, style: AppTextStyles.titleLarge),
                            if (releaseYear(movie.releaseDate)
                                case final year?) ...[
                              const SizedBox(height: 4),
                              Text(year, style: AppTextStyles.bodySmall),
                            ],
                          ],
                        ),
                      ),
                      const FavoriteButton(),
                    ],
                  ),
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
                  // 현재 세션에서 등록한 평점 카드 (등록 response의 Rating 객체)
                  if (viewModel.myRating case final rating?) ...[
                    const Divider(height: 32),
                    _MyRatingCard(
                      score: rating.score,
                      comment: rating.comment,
                      busy: viewModel.submitStatus == SubmitStatus.submitting,
                      onEdit: _openRatingDialog,
                      onDelete: _confirmDelete,
                    ),
                  ],
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
                child: FilledButton.icon(
                  // v7: memberId 없이 로그인 토큰만으로 등록합니다.
                  onPressed:
                      viewModel.canWrite &&
                          viewModel.submitStatus != SubmitStatus.submitting
                      ? _openRatingDialog
                      : null,
                  icon: const Icon(Icons.rate_review),
                  label: Text(viewModel.myRating == null ? '평점 남기기' : '평점 수정'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 현재 세션에서 등록한 평점 카드. v7 PATCH/DELETE로 수정·삭제합니다.
class _MyRatingCard extends StatelessWidget {
  const _MyRatingCard({
    required this.score,
    required this.comment,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final int score;
  final String? comment;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.violetLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('내 평점', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          RatingBarIndicator(
            rating: score.toDouble(),
            itemCount: 5,
            itemSize: 20,
            itemBuilder: (context, index) =>
                const Icon(Icons.star, color: AppColors.violet),
          ),
          if (comment case final text?) ...[
            const SizedBox(height: 8),
            Text(text, style: AppTextStyles.bodyMedium),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: busy ? null : onEdit,
                child: const Text('수정'),
              ),
              TextButton(
                onPressed: busy ? null : onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade800,
                ),
                child: const Text('삭제'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
