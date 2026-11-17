import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/rating_dto.dart';
import '../data/models/rating_with_movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/movielog_button.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MyRatingsViewModel>();
    final selecting = viewModel.isSelecting;

    return PopScope(
      // 다중 삭제 중에는 화면 이탈을 막습니다.
      canPop: !viewModel.isDeletingSelected,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: viewModel.isDeletingSelected ? null : () => context.pop(),
          ),
          title: Text(
            selecting ? '${viewModel.selectedRatingIds.length}개 선택' : '내가 등록한 평점',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.violet),
          ),
          actions: [
            if (viewModel.status == MyRatingsLoadStatus.success)
              TextButton(
                onPressed: viewModel.isDeletingSelected
                    ? null
                    : (selecting ? viewModel.cancelSelecting : viewModel.startSelecting),
                child: Text(selecting ? '취소' : '편집'),
              ),
          ],
        ),
        bottomNavigationBar: selecting
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: MovieLogButton(
                    label: '선택한 ${viewModel.selectedRatingIds.length}개 삭제',
                    width: double.infinity,
                    onPressed: viewModel.selectedRatingIds.isEmpty
                        ? null
                        : () => _onDeleteSelectedPressed(context),
                  ),
                ),
              )
            : null,
        body: SafeArea(
          child: LoadingOverlay(
            isLoading: viewModel.isDeletingSelected,
            child: RefreshIndicator(
              onRefresh: () => viewModel.load(),
              child: _buildBody(context, viewModel),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, MyRatingsViewModel viewModel) {
    switch (viewModel.status) {
      case MyRatingsLoadStatus.idle:
      case MyRatingsLoadStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.violet),
        );

      case MyRatingsLoadStatus.error:
        // 저장 성공 후 GET만 실패한 경우: 쓰기를 다시 보내지 않고 조회만 재시도합니다.
        return _ErrorView(
          message: viewModel.refreshWarning ??
              viewModel.message ??
              '평점을 불러오지 못했습니다.',
          retryLabel: viewModel.refreshWarning != null ? '조회 다시 시도' : '다시 시도',
          onRetry: () => viewModel.load(),
        );

      case MyRatingsLoadStatus.empty:
        return _EmptyView(onRefresh: () => viewModel.load());

      case MyRatingsLoadStatus.success:
        return _SuccessView(
          ratings: viewModel.ratings,
          message: viewModel.message,
          selecting: viewModel.isSelecting,
          selectedIds: viewModel.selectedRatingIds,
        );
    }
  }
}

Future<void> _onDeleteSelectedPressed(BuildContext context) async {
  final viewModel = context.read<MyRatingsViewModel>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('선택한 평점을 삭제할까요?'),
      content: const Text('삭제한 평점은 복구할 수 없습니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  // Dialog는 바로 닫히고, 삭제는 ViewModel이 이어받아 로딩 오버레이로 표시합니다.
  if (confirmed != true) return;
  await viewModel.deleteSelectedRatings();
}

Future<void> _onEditPressed(BuildContext context, RatingDto rating) async {
  final viewModel = context.read<MyRatingsViewModel>();
  final messenger = ScaffoldMessenger.of(context);
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막습니다.
    builder: (_) => RatingDialog(
      initialScore: rating.score,
      initialComment: rating.comment, // null이면 빈 칸
      onSubmit: (score, comment) => viewModel.updateRating(
        ratingId: rating.ratingId,
        score: score,
        comment: comment, // null이면 기존 후기를 지우겠다는 의도로 명시 전송
      ),
    ),
  );
  if (saved != true) return;
  messenger.showSnackBar(const SnackBar(content: Text('평점을 수정했습니다.')));
}

Future<void> _onDeletePressed(BuildContext context, RatingDto rating) async {
  final viewModel = context.read<MyRatingsViewModel>();
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeleteRatingDialog(
      onConfirm: () => viewModel.deleteRating(rating.ratingId),
    ),
  );
  if (confirmed != true) return; // 취소하면 API 요청 없음
  messenger.showSnackBar(const SnackBar(content: Text('평점을 삭제했습니다.')));
}

class _DeleteRatingDialog extends StatefulWidget {
  const _DeleteRatingDialog({required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  State<_DeleteRatingDialog> createState() => _DeleteRatingDialogState();
}

class _DeleteRatingDialogState extends State<_DeleteRatingDialog> {
  bool _isDeleting = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is StateError
              ? error.message
              : '삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.'),
        ),
      );
    }
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.ratings,
    required this.selecting,
    required this.selectedIds,
    this.message,
  });

  final List<RatingWithMovie> ratings;
  final String? message;
  final bool selecting;
  final Set<int> selectedIds;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        if (message != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ...ratings.map(
          (entry) => _RatingCard(
            entry: entry,
            selecting: selecting,
            selected: selectedIds.contains(entry.rating.ratingId),
          ),
        ),
      ],
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({
    required this.entry,
    required this.selecting,
    required this.selected,
  });

  final RatingWithMovie entry;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final movie = entry.movie;
    final rating = entry.rating;

    final dateStr =
        '${rating.createdAt.year}.${rating.createdAt.month.toString().padLeft(2, '0')}.${rating.createdAt.day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 영화 포스터
          TmdbPosterImage(
            posterPath: movie?.posterPath,
            width: 75,
            height: 105,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(width: 14),
          // 영화 및 평점 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 영화 제목
                Text(
                  movie?.title ?? '영화 ID: #${rating.movieId}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // 별점 표시
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      final isFilled = index < rating.score;
                      return Icon(
                        isFilled ? Icons.star : Icons.star_border,
                        size: 18,
                        color: Colors.amber,
                      );
                    }),
                    const SizedBox(width: 6),
                    Text(
                      '${rating.score} / 5',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
                // 코멘트 (null이 아닐 때만 표시)
                if (rating.comment != null && rating.comment!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warmWhite,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.lightGray),
                    ),
                    child: Text(
                      rating.comment!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.black,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                // 등록일
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.gray,
                  ),
                ),
              ],
            ),
          ),
          // 우측: 선택 모드면 체크박스, 아니면 수정·삭제 버튼
          if (selecting)
            Checkbox(
              value: selected,
              onChanged: (_) => context
                  .read<MyRatingsViewModel>()
                  .toggleSelected(rating.ratingId),
            )
          else
            Column(
              children: [
                IconButton(
                  tooltip: '수정',
                  icon: const Icon(Icons.edit_outlined, color: AppColors.violet),
                  onPressed: () => _onEditPressed(context, rating),
                ),
                IconButton(
                  tooltip: '삭제',
                  icon: const Icon(Icons.delete_outline, color: AppColors.gray),
                  onPressed: () => _onDeletePressed(context, rating),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.warmWhite,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.rate_review_outlined,
                  size: 36,
                  color: AppColors.gray,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '아직 등록한 평점이 없어요',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                '감상한 영화에 나만의 평점과 리뷰를 남겨보세요.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.gray,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('새로고침'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.violet,
                  side: const BorderSide(color: AppColors.violet),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    this.retryLabel = '다시 시도',
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 36,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '오류가 발생했습니다',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(retryLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
