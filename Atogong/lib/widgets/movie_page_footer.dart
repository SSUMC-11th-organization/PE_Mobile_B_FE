import 'package:flutter/material.dart';

import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import 'movielog_button.dart';

/// 목록 맨 아래에 붙는 더 보기 / 추가 로딩 / 같은 page 재시도 / 끝 표시.
/// 영화 목록 화면과 검색 화면이 함께 사용
class MoviePageFooter extends StatelessWidget {
  const MoviePageFooter({super.key, required this.vm});

  final PagedMoviesViewModel vm;

  @override
  Widget build(BuildContext context) {
    // 마지막 page: 더 보기를 숨기고 끝 상태를 표시
    if (!vm.hasMore && !vm.isLoadingMore && vm.loadMoreError == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('더 이상 조회할 페이지가 없습니다.', textAlign: TextAlign.center),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (vm.loadMoreError != null) ...[
            Text(vm.loadMoreError!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
          ],
          // 요청 중에는 기존 카드를 그대로 둔 채 버튼만 로딩으로 바뀌고 비활성화됨
          MovieLogButton(
            width: double.infinity,
            label: vm.loadMoreError == null ? '더 보기' : '다음 페이지 다시 시도',
            isLoading: vm.isLoadingMore,
            onPressed: vm.phase == LoadPhase.ready ? vm.loadNextPage : null,
          ),
        ],
      ),
    );
  }
}
