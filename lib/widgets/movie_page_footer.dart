import 'package:flutter/material.dart';

import '../view_models/paged_movies_view_model.dart';
import 'movielog_button.dart';

class MoviePageFooter extends StatelessWidget {
  const MoviePageFooter({super.key, required this.viewModel});

  final PagedMoviesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (!viewModel.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('더 이상 조회할 페이지가 없습니다.', textAlign: TextAlign.center),
      );
    }
    final error = viewModel.loadMoreError;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(error),
            ),
          MovieLogButton(
            width: double.infinity,
            label: error == null ? '더 보기' : '다음 페이지 다시 시도',
            isLoading: viewModel.isLoadingMore,
            onPressed: viewModel.loadNextPage,
          ),
        ],
      ),
    );
  }
}
