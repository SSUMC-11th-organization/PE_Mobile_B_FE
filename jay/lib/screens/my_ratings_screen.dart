import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jay/data/models/rating_dto.dart';
import 'package:jay/data/services/rating_api_service.dart';
import 'package:jay/view_models/my_rating_view_model.dart';
import 'package:jay/widgets/common_app_bar.dart';
import 'package:jay/widgets/movie_list_states.dart';
import 'package:jay/widgets/movielog_button.dart';
import 'package:jay/widgets/rating_dialog.dart';
import 'package:provider/provider.dart';
import 'package:jay/data/models/rating_with_movie.dart';
import 'package:jay/theme/app_colors.dart';
import 'package:jay/theme/app_text_styles.dart';
import 'package:jay/widgets/tmdb_poster_image.dart';

/// 학습용 memberId 1의 평점 목록 화면입니다.
/// root Navigator 위에 열리므로 하단 NavigationBar가 보이지 않습니다.
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // leading을 지정하지 않으면 pop 가능한 화면에서 BackButton이 자동으로 표시됩니다.
      appBar: const CommonAppBar(title: '내가 등록한 평점', centerTitle: true),
      body: Consumer<MyRatingsViewModel>(
        builder: (context, viewModel, child) {
          switch (viewModel.status) {
            case MyRatingsLoadStatus.idle:
            case MyRatingsLoadStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case MyRatingsLoadStatus.empty:
              return const Center(child: Text('등록된 평점이 없습니다.'));
            case MyRatingsLoadStatus.error:
              return MovieListError(
                // 저장은 성공했지만 재조회만 실패한 경우를 구분해서 안내합니다.
                message: viewModel.refreshWarning ?? viewModel.message,
                onRetry: viewModel.load,
              );
            case MyRatingsLoadStatus.success:
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                // 영화 정보 일부 누락 안내(message)가 있으면 맨 위에 한 줄 더 그립니다.
                itemCount:
                    viewModel.ratings.length +
                    (viewModel.message != null ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (viewModel.message != null) {
                    if (index == 0) {
                      return Text(
                        viewModel.message!,
                        style: AppTextStyles.bodySmall,
                      );
                    }
                    index -= 1;
                  }
                  return _RatingCard(entry: viewModel.ratings[index]);
                },
              );
          }
        },
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.entry});

  final RatingWithMovie entry;

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating;
    final movie = entry.movie; // TMDB에서 못 찾았으면 null
    final comment = rating.comment;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // posterPath가 null이면 TmdbPosterImage가 알아서 placeholder를 그립니다.
            child: TmdbPosterImage(
              posterPath: movie?.posterPath,
              width: 72,
              height: 104,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie?.title ?? '영화 #${rating.movieId}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '별점 ${rating.score} / 5',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.violet,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // comment가 null이면 화면에 그리지 않습니다.
                if (comment != null) ...[
                  const SizedBox(height: 8),
                  Text(comment, style: AppTextStyles.bodySmall),
                ],
                const SizedBox(height: 8),
                Text(
                  _formatDate(rating.createdAt),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.gray,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 카드 오른쪽 개별 수정·삭제 버튼
          Column(
            children: [
              TextButton(
                onPressed: () => onEditPressed(context, rating),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.violetLight,
                  foregroundColor: AppColors.violet,
                ),
                child: const Text('수정'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => onDeletePressed(context, rating),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
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

  String _formatDate(DateTime date) {
    final local = date.toLocal(); // 서버는 UTC(Z)로 내려줍니다.
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}.$month.$day';
  }
}

Future<void> onEditPressed(BuildContext context, RatingDto rating) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막습니다.
    builder: (_) => RatingDialog(
      initialScore: rating.score,
      initialComment: rating.comment, // null이면 TextField가 빈 칸으로 시작합니다.
      onSubmit: (score, comment) =>
          context.read<MyRatingsViewModel>().updateRating(
            ratingId: rating.ratingId,
            score: score,
            comment: comment,
          ),
    ),
  );

  if (!context.mounted || saved != true) return;
}

Future<void> onDeletePressed(BuildContext context, RatingDto rating) async {
  await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 삭제 중 바깥 탭으로 닫히는 것도 막습니다.
    builder: (_) => _DeleteRatingDialog(
      onConfirm: () =>
          context.read<MyRatingsViewModel>().deleteRating(rating.ratingId),
    ),
  );
  // Dialog는 실제로 삭제까지 마쳤을 때만 true를 반환합니다.
  // 성공 후 목록 재조회는 deleteRating 내부에서 처리하므로 여기서 할 일은 없습니다.
}

class _DeleteRatingDialog extends StatefulWidget {
  const _DeleteRatingDialog({required this.onConfirm});
  final Future<void> Function() onConfirm;

  @override
  State<StatefulWidget> createState() => _DeleteRatingDialogState();
}

class _DeleteRatingDialogState extends State<_DeleteRatingDialog> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        title: const Text('평점을 삭제할까요?'),
        content: const Text('삭제한 평점은 복구할 수 없습니다.'),
        actions: [
          MovieLogButton(
            label: '취소',
            onPressed: _isDeleting ? null : () => Navigator.pop(context, false),
          ),
          MovieLogButton(
            label: '삭제',
            isLoading: _isDeleting,
            onPressed: _isDeleting ? null : _onConfirm,
          ),
        ],
      ),
    );
  }

  Future<void> _onConfirm() async {
    setState(() => _isDeleting = true);
    try {
      await widget.onConfirm();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      // 403(본인 평점 아님)·404(평점 없음)를 서버 message로 구분해서 안내합니다.
      final message = error is DioException
          ? writeErrorMessage(error)
          : '삭제하지 못했습니다. 잠시 후 다시 시도해주세요.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
