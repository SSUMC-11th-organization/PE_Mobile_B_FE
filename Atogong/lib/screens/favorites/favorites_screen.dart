import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/favorite_list_item.dart';
import '../../data/models/tmdb_movie_dto.dart';
import '../../view_models/favorites_view_model.dart';
import '../../view_models/load_phase.dart';
import '../../widgets/movie_card.dart';
import '../../widgets/movielog_button.dart';

/// 마이페이지의 자식 화면. root Navigator 위에 떠서 하단 NavigationBar가 없고, AppBar 뒤로가기로 복귀.
/// 목록 / 빈 목록 / 조회 오류 / 영화 정보 한 건 실패를 서로 다른 화면으로 구분
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.onOpenMovie});

  // 상세로 이동했다가 돌아올 때까지 기다릴 수 있도록 Future를 반환
  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FavoritesViewModel>().refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('내 즐겨찾기'), centerTitle: true),
    body: Consumer<FavoritesViewModel>(
      builder: (context, vm, _) {
        if (vm.phase == LoadPhase.idle || vm.phase == LoadPhase.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (vm.phase == LoadPhase.empty) {
          return const Center(child: Text('아직 즐겨찾기한 영화가 없습니다.'));
        }

        if (vm.phase == LoadPhase.error) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(vm.errorMessage ?? '조회 오류입니다.'),
                const SizedBox(height: 12),
                MovieLogButton(label: '다시 시도', onPressed: vm.refresh),
              ],
            ),
          );
        }

        // 영화 목록 화면과 같은 2열 Grid에 기존 영화 카드(MovieCard)를 재사용
        return RefreshIndicator(
          onRefresh: vm.refresh,
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 24,
              childAspectRatio: 0.55,
            ),
            itemCount: vm.items.length,
            itemBuilder: (context, index) {
              final item = vm.items[index], movie = item.movie;

              // 영화 정보를 못 가져온 카드만 placeholder + 재조회. 다른 카드는 그대로 둠
              if (movie == null) {
                return _MissingMovieCard(item: item, onRetry: vm.refresh);
              }

              return MovieCard(
                movie: movie,
                onTap: () async {
                  await widget.onOpenMovie(movie);

                  if (!mounted) return;

                  // 상세에서 해제하고 돌아왔을 수 있으므로 목록을 다시 조회
                  await vm.refresh();
                },
              );
            },
          ),
        );
      },
    ),
  );
}

/// TMDB에서 영화 정보를 가져오지 못한 즐겨찾기. 제목·포스터 대신 movieId와 재조회 버튼을 표시
class _MissingMovieCard extends StatelessWidget {
  const _MissingMovieCard({required this.item, required this.onRetry});

  final FavoriteListItem item;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'TMDB #${item.favorite.movieId}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          item.errorMessage ?? '정보가 없습니다.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        MovieLogButton(
          width: double.infinity,
          label: '정보 재조회',
          onPressed: onRetry,
        ),
      ],
    );
  }
}
