import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/rating_dto.dart';
import '../../data/services/rating_api_service.dart';
import '../../view_models/my_ratings_view_model.dart';
import '../../widgets/movielog_button.dart';
import '../movie_detail/widgets/rating_dialog.dart';
import 'widgets/rating_card.dart';

/// 마이페이지의 자식 화면. root Navigator 위에 떠서 하단 NavigationBar가 없고, AppBar 뒤로가기로 복귀
/// 8주차: 이번 로그인 세션에서 등록한 평점을 보여주고, 카드별 수정·삭제를 v7 토큰 기반 API로 요청
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  // v7에는 토큰 기반 "내 평점 목록 GET"이 없어서 생기는 한계를 화면에도 안내
  static const _sessionNotice = '이번 로그인 이후 등록한 평점만 표시됩니다.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내가 등록한 평점'), centerTitle: true),
      body: SafeArea(
        child: Consumer<MyRatingsViewModel>(
          builder: (context, viewModel, child) {
            switch (viewModel.status) {
              case MyRatingsLoadStatus.idle:
              case MyRatingsLoadStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case MyRatingsLoadStatus.empty:
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '아직 등록한 평점이 없습니다.\n$_sessionNotice',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              case MyRatingsLoadStatus.success:
                return _SuccessView(viewModel: viewModel);
            }
          },
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final message = viewModel.message;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            MyRatingsScreen._sessionNotice,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        // 일부 영화 정보 조회 실패·직전 쓰기 실패 안내 (평점 목록은 그대로)
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        for (final entry in viewModel.ratings)
          RatingCard(
            entry: entry,
            onEdit: () => onEditPressed(context, entry.rating),
            onDelete: () => onDeletePressed(context, entry.rating),
          ),
      ],
    );
  }
}

/// 수정: 등록과 같은 RatingDialog를 기존 별점·코멘트로 채워서 다시 엶
Future<void> onEditPressed(BuildContext context, RatingDto rating) async {
  await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막음
    builder: (_) => RatingDialog(
      initialScore: rating.score,
      initialComment: rating.comment, // null이면 TextField가 빈 칸으로 시작
      onSubmit: (score, comment) async {
        try {
          // score는 항상 보내고, comment는 Dialog에 남아 있는 값을 그대로 보냄 (비우면 null = 후기 삭제)
          await context.read<MyRatingsViewModel>().updateRating(
            ratingId: rating.ratingId,
            score: score,
            comment: comment,
          );
        } on DioException catch (error) {
          // 쓰기 실패만 Dialog로 넘김. 서버 message(400/403/404)를 Dialog가 그대로 표시.
          // 401(세션 만료)은 ViewModel이 세션을 정리해 Router가 로그인 화면으로 보냄
          throw StateError(writeErrorMessage(error));
        }
      },
    ),
  );
  // 성공 시 목록 갱신은 ViewModel이 이미 끝냈고, 취소·실패는 별도 처리 없음
}

/// 삭제: 되돌릴 수 없으므로 확인 Dialog를 거침. 취소하면 삭제 API를 호출하지 않음
Future<void> onDeletePressed(BuildContext context, RatingDto rating) async {
  await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 삭제 중 바깥 탭으로 닫히는 것도 막음
    builder: (_) => _DeleteRatingDialog(
      onConfirm: () async {
        try {
          await context.read<MyRatingsViewModel>().deleteRating(
            rating.ratingId,
          );
        } on DioException catch (error) {
          throw StateError(writeErrorMessage(error));
        }
      },
    ),
  );
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
      canPop: !_isDeleting, // 삭제 요청 중에는 뒤로가기로 닫히지 않음
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
      Navigator.pop(context, true); // 실제로 삭제까지 마쳤을 때만 true
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false); // 버튼을 되돌려 다시 시도할 수 있게 함
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message
                : '삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.',
          ),
        ),
      );
    }
  }
}
