import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/movie_list_view_model.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';

// 영화 목록 탭 — TMDB 장르 Chip + Discover 목록(Loading/Empty/Error/Success)
// 요청은 라우트에서 ViewModel 생성 시 시작 — 화면은 상태만 보고 그림
class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<MovieListViewModel>(
          builder: (context, viewModel, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 장르 필터 — 장르가 많아 가로 스크롤
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      _GenreChip(
                        label: '전체',
                        genreId: null,
                        viewModel: viewModel,
                      ),
                      for (final genre in viewModel.genres)
                        _GenreChip(
                          label: genre.name,
                          genreId: genre.id,
                          viewModel: viewModel,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildBody(viewModel)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(MovieListViewModel viewModel) {
    switch (viewModel.status) {
      case MovieListStatus.idle:
      case MovieListStatus.loading:
        return const MovieListLoading();
      case MovieListStatus.error:
        return MovieListError(
          message: viewModel.message,
          onRetry: viewModel.retry,
        );
      case MovieListStatus.empty:
        return const MovieListEmpty();
      case MovieListStatus.success:
        return MovieGrid(movies: viewModel.movies);
    }
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({
    required this.label,
    required this.genreId,
    required this.viewModel,
  });

  final String label;
  final int? genreId; // null이면 '전체'
  final MovieListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: viewModel.selectedGenreId == genreId,
        // onSelected가 null이면 Chip이 비활성화됨 → 로딩 중에는 장르 변경 불가
        onSelected: viewModel.isLoading
            ? null
            : (_) => viewModel.selectGenre(genreId),
      ),
    );
  }
}
