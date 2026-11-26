import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/favorite_list_item.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/load_phase.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_card.dart';
import '../widgets/movielog_button.dart';

// 내 즐겨찾기 — root Navigator에 띄워 하단 NavigationBar 없이 표시
// 목록 / 빈 목록 / 조회 오류 / 영화 정보 일부 실패를 서로 다른 모습으로 구분
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    // 진입 시 한 번 조회 (build에서는 조회하지 않음)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoritesViewModel>().refresh();
    });
  }

  // 상세로 갔다가 돌아오면 목록을 다시 조회 → 상세에서 해제한 영화가 사라짐
  Future<void> _openMovie(TmdbMovieDto movie) async {
    final vm = context.read<FavoritesViewModel>();
    await context.push('/movies/${movie.id}', extra: movie);
    if (!mounted) return;
    await vm.refresh(); // ViewModel이 현재 세션인지 다시 확인함
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '내 즐겨찾기',
        centerTitle: true,
        onBack: () => context.canPop() ? context.pop() : context.go('/my'),
      ),
      body: SafeArea(
        child: Consumer<FavoritesViewModel>(
          builder: (context, vm, _) {
            final isLoading =
                vm.phase == LoadPhase.idle || vm.phase == LoadPhase.loading;

            // 첫 조회 중 (보여 줄 목록이 아직 없음)
            if (isLoading && vm.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // 목록 조회 자체가 실패
            if (vm.phase == LoadPhase.error) {
              return _CenterMessage(
                icon: Icons.error_outline,
                iconColor: AppColors.error,
                message: vm.errorMessage ?? '내 즐겨찾기 목록을 불러오지 못했습니다.',
                action: MovieLogButton(label: '다시 시도', onPressed: vm.refresh),
              );
            }

            // 조회는 성공했지만 즐겨찾기가 없음
            if (vm.phase == LoadPhase.empty) {
              return RefreshIndicator(
                onRefresh: vm.refresh,
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: const _CenterMessage(
                        icon: Icons.bookmark_border,
                        iconColor: AppColors.gray,
                        message: '아직 즐겨찾기한 영화가 없습니다.\n영화 상세에서 북마크를 눌러 추가해 보세요.',
                      ),
                    ),
                  ),
                ),
              );
            }

            // 목록 (상세에서 돌아와 다시 조회하는 동안에는 기존 목록 + 상단 진행 표시)
            return Column(
              children: [
                if (isLoading) const LinearProgressIndicator(minHeight: 2),
                if (vm.hasPartialFailure) const _PartialFailureBanner(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: vm.refresh,
                    child: GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: vm.items.length,
                      itemBuilder: (context, index) {
                        final item = vm.items[index];
                        final movie = item.movie;
                        if (movie == null) {
                          return _MissingMovieCard(
                            item: item,
                            isRetrying: vm.isRetrying(item.favorite.movieId),
                            onRetry: () =>
                                vm.retryMovie(item.favorite.movieId),
                          );
                        }
                        // 기존 영화 카드 재사용 — 탭하면 상세로 갔다가 돌아와서 목록 갱신
                        return MovieCard(
                          movie: movie,
                          onTap: () => _openMovie(movie),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// 영화 정보 일부 실패 안내 — 목록은 그대로 두고 상단에만 표시
class _PartialFailureBanner extends StatelessWidget {
  const _PartialFailureBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.error.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.error),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '일부 영화 정보를 불러오지 못했습니다. 카드의 다시 조회를 눌러 주세요.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// TMDB 정보를 못 가져온 카드 — "영화 #{movieId}" placeholder + 이 카드만 재조회
class _MissingMovieCard extends StatelessWidget {
  const _MissingMovieCard({
    required this.item,
    required this.isRetrying,
    required this.onRetry,
  });

  final FavoriteListItem item;
  final bool isRetrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.gray.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.broken_image_outlined,
                  size: 36,
                  color: AppColors.gray,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    item.errorMessage ?? '영화 정보가 없습니다.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                const SizedBox(height: 4),
                isRetrying
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('다시 조회'),
                      ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '영화 #${item.favorite.movieId}',
          style: AppTextStyles.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// 가운데 아이콘 + 문구 (+ 버튼) — 빈 목록·조회 오류 공통 모양 (아이콘·색·버튼으로 구분)
class _CenterMessage extends StatelessWidget {
  const _CenterMessage({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
