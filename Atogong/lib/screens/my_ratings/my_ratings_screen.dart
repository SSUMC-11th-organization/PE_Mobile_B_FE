import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../view_models/my_ratings_view_model.dart';
import '../../widgets/movielog_button.dart';
import 'widgets/rating_card.dart';

/// 마이페이지의 자식 화면. root Navigator 위에 떠서 하단 NavigationBar가 없고, AppBar 뒤로가기로 복귀
/// 로그인 전이라 '현재 사용자'가 아닌 학습용 memberId 1의 공개 데이터
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

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
                return const Center(child: Text('아직 등록한 평점이 없습니다.'));
              case MyRatingsLoadStatus.error:
                return _ErrorView(
                  message: viewModel.message ?? '평점을 불러오지 못했습니다.',
                  onRetry: viewModel.load,
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            // 고정 너비(160): 화면 크기와 무관하게 같은 크기
            MovieLogButton(label: '다시 시도', width: 160, onPressed: onRetry),
          ],
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
        // 일부 영화 정보 조회 실패 안내 (평점 목록은 그대로)
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        for (final entry in viewModel.ratings) RatingCard(entry: entry),
      ],
    );
  }
}
