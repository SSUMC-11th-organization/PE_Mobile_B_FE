import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/favorite_list_item.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/load_phase.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_list_states.dart';
import '../widgets/paged_movie_grid.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoritesViewModel>().refresh();
    });
  }

  Widget _card(FavoritesViewModel vm, FavoriteListItem item) {
    final movie = item.movie;
    if (movie == null) {
      return Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image_outlined, size: 40),
            const SizedBox(height: 8),
            Text('영화 #${item.favorite.movieId}'),
            const Text('영화 정보를 불러오지 못했습니다.', textAlign: TextAlign.center),
            TextButton(
              onPressed: () => vm.retryMovie(item.favorite.movieId),
              child: const Text('정보 재조회'),
            ),
          ],
        ),
      );
    }
    return MovieCard(
      movie: movie,
      onTap: () async {
        await context.push('/movies/${movie.id}', extra: movie);
        // 상세에서 해제했을 수 있으므로 다시 조회합니다.
        if (mounted) await vm.refresh();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FavoritesViewModel>();
    return Scaffold(
      appBar: CommonAppBar(
        title: '내 즐겨찾기',
        centerTitle: true,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        child: switch (vm.phase) {
          LoadPhase.idle || LoadPhase.loading => const MovieListLoading(),
          LoadPhase.empty => const MovieListEmpty(
              message: '아직 즐겨찾기한 영화가 없습니다.',
            ),
          LoadPhase.error => MovieListError(
              message: vm.errorMessage ?? '조회 오류입니다.',
              onRetry: vm.refresh,
            ),
          LoadPhase.ready => RefreshIndicator(
              onRefresh: vm.refresh,
              child: GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                gridDelegate: movieGridDelegate,
                itemCount: vm.items.length,
                itemBuilder: (context, index) => _card(vm, vm.items[index]),
              ),
            ),
        },
      ),
    );
  }
}
