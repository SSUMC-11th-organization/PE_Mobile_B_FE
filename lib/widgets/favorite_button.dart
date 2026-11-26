import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/favorite_detail_view_model.dart';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key});

  Future<void> _toggle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await context.read<FavoriteDetailViewModel>().toggle();
    if (!context.mounted || message == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FavoriteDetailViewModel>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 62,
          height: 48,
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
                  tooltip: vm.isFavorite ? '즐겨찾기 해제' : '즐겨찾기 등록',
                  color: AppColors.violet,
                  onPressed:
                      vm.hasLoadedStatus ? () => _toggle(context) : null,
                  icon: Icon(
                    vm.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  ),
                ),
        ),
        const Text('즐겨찾기'),
        // 첫 여부 조회에 실패했을 때만 새로고침 버튼을 보여 줍니다.
        if (!vm.hasLoadedStatus && !vm.isLoading && vm.errorMessage != null)
          IconButton(
            tooltip: '여부 다시 확인',
            color: AppColors.violet,
            onPressed: vm.load,
            icon: const Icon(Icons.refresh),
          ),
      ],
    );
  }
}
