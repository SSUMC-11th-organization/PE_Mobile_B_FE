import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/rating_with_movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/movielog_button.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

// 학습용 회원의 평점 목록 화면 — 조회 + 본인 평점 수정/삭제
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '학습용 회원(memberId ${context.read<MyRatingsViewModel>().memberId})의 평점입니다',
                style: AppTextStyles.bodySmall,
              ),
            ),
            // 쓰기는 성공했지만 재조회가 실패한 경우 — 조회만 다시 시도(쓰기 재전송 없음)
            Consumer<MyRatingsViewModel>(
              builder: (context, vm, _) {
                final warning = vm.refreshWarning;
                if (warning == null) return const SizedBox.shrink();
                return _NoticeBanner(
                  warning,
                  action: TextButton(
                    onPressed: vm.status == MyRatingsLoadStatus.loading
                        ? null
                        : vm.load,
                    child: const Text('조회 다시 시도'),
                  ),
                );
              },
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
  const _NoticeBanner(this.text, {this.action});

  final String text;
  final Widget? action; // 선택: 오른쪽 버튼

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
          ?action,
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.entry});

  final RatingWithMovie entry;

  Future<void> _openEditDialog(BuildContext context) async {
    final vm = context.read<MyRatingsViewModel>();
    final rating = entry.rating;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingDialog(
        initialScore: rating.score,
        initialComment: rating.comment,
        onSubmit: (score, comment) => vm.updateRating(
          ratingId: rating.ratingId,
          score: score,
          comment: comment,
        ),
      ),
    );
  }

  Future<void> _openDeleteDialog(BuildContext context) async {
    final vm = context.read<MyRatingsViewModel>();
    final ratingId = entry.rating.ratingId;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteRatingDialog(
        onDelete: () => vm.deleteRating(ratingId),
      ),
    );
  }

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
            // 이 목록은 본인 평점만 있으므로 항상 수정/삭제 가능
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: '평점 수정',
                  onPressed: () => _openEditDialog(context),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '평점 삭제',
                  onPressed: () => _openDeleteDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 삭제 확인 다이얼로그 — 삭제 성공 시 pop(true), 취소 시 API 호출 없이 pop(false)
class _DeleteRatingDialog extends StatefulWidget {
  const _DeleteRatingDialog({required this.onDelete});

  final Future<void> Function() onDelete;

  @override
  State<_DeleteRatingDialog> createState() => _DeleteRatingDialogState();
}

class _DeleteRatingDialogState extends State<_DeleteRatingDialog> {
  bool _isDeleting = false;

  Future<void> _delete() async {
    if (_isDeleting) return;
    setState(() {
      _isDeleting = true;
    });
    try {
      await widget.onDelete();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      // 실패해도 다이얼로그는 유지 → 다시 삭제하거나 취소할 수 있음
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        title: const Text('평점을 삭제할까요?'),
        content: const Text('삭제한 평점은 복구할 수 없습니다.'),
        actions: [
          MovieLogButton(
            label: '취소',
            onPressed:
                _isDeleting ? null : () => Navigator.of(context).pop(false),
          ),
          MovieLogButton(
            label: '삭제',
            isLoading: _isDeleting,
            onPressed: _isDeleting ? null : _delete,
          ),
        ],
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
