import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../view_models/load_phase.dart';
import '../../view_models/movie_list_view_model.dart';
import '../../view_models/paged_movies_view_model.dart';
import '../../widgets/movie_page_footer.dart';
import 'widgets/genre_chips.dart';
import 'widgets/movie_grid.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';

/// 9주차: 첫 page만 표시하고 카드 목록 아래 footer의 "더 보기"로 다음 page를 이어 붙임.
/// 장르 상태는 MovieListViewModel, 영화 목록·page 상태는 PagedMoviesViewModel이 관리
class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final genreViewModel = context.watch<MovieListViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '영화',
          style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
        ),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      body: Consumer<PagedMoviesViewModel>(
        builder: (context, paged, _) {
          return Column(
            children: [
              GenreChips(
                genres: genreViewModel.genres,
                selectedId: genreViewModel.selectedGenreId,
                // 요청 중에도 장르를 바꿀 수 있음. 이전 장르의 늦은 응답은 generation 비교로 버려짐
                onSelected: (genreId) {
                  context.read<MovieListViewModel>().selectGenre(genreId);
                  // 이전 목록을 비우고 새 장르의 첫 page부터 다시 요청
                  paged.loadInitial(genreId: genreId);
                },
              ),
              if (paged.phase == LoadPhase.ready)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${paged.movies.length}편',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              Expanded(
                child: switch (paged.phase) {
                  LoadPhase.idle ||
                  LoadPhase.loading => const MovieListLoading(),
                  LoadPhase.error => MovieListError(
                    onRetry: () {
                      context.read<MovieListViewModel>().loadGenres();
                      paged.loadInitial(
                        genreId: genreViewModel.selectedGenreId,
                      );
                    },
                  ),
                  LoadPhase.empty => const MovieListEmpty(),
                  LoadPhase.ready => MovieGrid(
                    // 장르가 바뀌면 Grid를 새로 만들어 새 목록이 맨 위에서 시작하게 함
                    key: ValueKey(genreViewModel.selectedGenreId),
                    movies: paged.movies,
                    footer: MoviePageFooter(vm: paged),
                  ),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
