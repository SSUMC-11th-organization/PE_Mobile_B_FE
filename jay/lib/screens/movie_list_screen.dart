import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/movie_list_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/genre_chips.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_states.dart';

// 상태는 MovieListViewModel이 들고 있고, 화면은 구독해서 그리기만 한다
class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      body: Column(
        children: [
          // 장르 목록·선택값·로딩 여부가 바뀔 때 칩 영역만 다시 그린다
          Consumer<MovieListViewModel>(
            builder: (context, viewModel, child) => GenreChips(
              genres: viewModel.genres,
              selectedId: viewModel.selectedGenreId,
              // 요청 중에는 null을 넘겨 장르 변경을 막는다
              onSelected: viewModel.isLoading ? null : viewModel.selectGenre,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer<MovieListViewModel>(
              builder: (context, viewModel, child) {
                return switch (viewModel.status) {
                  MovieListLoadStatus.idle ||
                  MovieListLoadStatus.loading => const MovieListLoading(),
                  MovieListLoadStatus.error => MovieListError(
                    message: viewModel.message,
                    onRetry: viewModel.retry,
                  ),
                  MovieListLoadStatus.empty => const MovieListEmpty(),
                  MovieListLoadStatus.success => MovieGrid(
                    movies: viewModel.movies,
                    genres: viewModel.genres,
                  ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}
