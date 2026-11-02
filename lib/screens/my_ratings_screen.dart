import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/rating_with_movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/movielog_button.dart';
import '../widgets/tmdb_poster_image.dart';

// 학습용 샘플 회원의 평점 목록 화면 (조회 전용 — 수정/삭제 없음)
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('내가 등록한 평점'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '학습용 샘플 회원(memberId $sampleMemberId)의 평점입니다',
                style: AppTextStyles.bodySmall,
              ),
            ),
            Expanded(
              child: Consumer<MyRatingsViewModel>(
                builder: (context, vm, _) {
                  switch (vm.status) {
                    case MyRatingsLoadStatus.idle:
                    case MyRatingsLoadStatus.loading:
                      return const Center(child: CircularProgressIndicator());
                    case MyRatingsLoadStatus.empty:
                      return const Center(
                        child: Text(
                          '아직 등록한 평점이 없습니다.',
                          style: AppTextStyles.bodyMedium,
                        ),
                      );
                    case MyRatingsLoadStatus.error:
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                vm.message ?? '',
                                style: AppTextStyles.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              MovieLogButton(
                                label: '다시 시도',
                                onPressed: vm.load,
                              ),
                            ],
                          ),
                        ),
                      );
                    case MyRatingsLoadStatus.success:
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (vm.message != null) _NoticeBanner(vm.message!),
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: vm.load,
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: vm.ratings.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) =>
                                    _RatingCard(entry: vm.ratings[index]),
                              ),
                            ),
                          ),
                        ],
                      );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: AppTextStyles.bodySmall),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.entry});

  final RatingWithMovie entry;

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating;
    final movie = entry.movie;
    final comment = rating.comment;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // movie == null이면 posterPath도 null → TmdbPosterImage가 회색 placeholder 표시
            SizedBox(
              width: 64,
              height: 96,
              child: TmdbPosterImage(posterPath: movie?.posterPath),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie?.title ?? '영화 정보 없음 (movieId: ${rating.movieId})',
                    style: AppTextStyles.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (var i = 0; i < 5; i++)
                        Icon(
                          i < rating.score ? Icons.star : Icons.star_border,
                          size: 18,
                          color: AppColors.violet,
                        ),
                    ],
                  ),
                  if (comment != null && comment.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(comment, style: AppTextStyles.bodyMedium),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(rating.createdAt),
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 'yyyy.MM.dd' (intl 없이 직접 0 패딩)
String _formatDate(DateTime dateTime) {
  final d = dateTime.toLocal();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}.$mm.$dd';
}
