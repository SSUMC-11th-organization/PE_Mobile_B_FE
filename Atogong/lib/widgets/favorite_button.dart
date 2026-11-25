import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/favorite_detail_view_model.dart';

/// 영화 상세의 제목·정보 텍스트 오른쪽에 두는 북마크 버튼.
/// 상태는 FavoriteDetailViewModel에서 읽고, 요청 중에는 북마크 자리에만 인디케이터를 표시
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key});

  // 3주차처럼 Snackbar로 결과를 안내. 문구는 화면 내부 상태가 아니라 서버 요청 결과를 따름
  Future<void> _toggle(BuildContext context, FavoriteDetailViewModel vm) async {
    await vm.toggle();
    // 세션 만료는 로그인 화면이 안내하므로 여기서 Snackbar를 또 띄우지 않음
    if (!context.mounted || vm.sessionExpired) return;
    final message =
        vm.errorMessage ?? (vm.isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoriteDetailViewModel>(
      builder: (context, vm, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 62,
              height: 64,
              child: vm.isLoading || vm.isSaving
                  ? const Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.violet,
                        ),
                      ),
                    )
                  : IconButton(
                      color: AppColors.violet,
                      // 첫 여부 조회가 끝나기 전에는 누를 수 없음
                      onPressed: vm.hasLoadedStatus
                          ? () => _toggle(context, vm)
                          : null,
                      icon: Icon(
                        vm.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                      ),
                    ),
            ),
            const Text('즐겨찾기'),
            // 첫 여부 조회에 실패했을 때만 북마크와 같은 너비의 새로고침 버튼을 보여 줌
            if (!vm.hasLoadedStatus && !vm.isLoading)
              SizedBox(
                width: 62,
                child: IconButton(
                  tooltip: '여부 다시 확인',
                  color: AppColors.violet,
                  onPressed: vm.load,
                  icon: const Icon(Icons.refresh),
                ),
              ),
          ],
        );
      },
    );
  }
}
