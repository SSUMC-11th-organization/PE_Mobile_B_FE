import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/favorite_detail_view_model.dart';

// 영화 상세의 제목/정보 텍스트 오른쪽 북마크 버튼 — RatingDialog는 그대로 둠
// 요청 중에는 북마크 자리에만 CircularProgressIndicator, 결과는 Snackbar로 안내
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key});

  Future<void> _toggle(BuildContext context, FavoriteDetailViewModel vm) async {
    final message = await vm.toggle();
    if (message == null || !context.mounted) return; // 세션 변경·만료면 안내 없음
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar() // 연속으로 눌러도 안내가 쌓이지 않게
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
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
                      tooltip: vm.isFavorite ? '즐겨찾기 해제' : '즐겨찾기',
                      onPressed:
                          vm.hasLoadedStatus ? () => _toggle(context, vm) : null,
                      icon: Icon(
                        vm.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                      ),
                    ),
            ),
            const Text('즐겨찾기'),
            // 첫 여부 조회에 실패했을 때만 북마크와 같은 너비의 새로고침 버튼
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
