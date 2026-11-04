import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../view_models/movie_list_view_model.dart';
import 'widgets/genre_chips.dart';
import 'widgets/movie_grid.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '영화',
          style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
        ),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      body: Consumer<MovieListViewModel>(
        builder: (context, viewModel, _) {
          return Column(
            children: [
              GenreChips(
                genres: viewModel.genres,
                selectedId: viewModel.selectedGenreId,
                enabled: !viewModel.isLoading,
                onSelected: (genreId) =>
                    context.read<MovieListViewModel>().selectGenre(genreId),
              ),
              if (viewModel.status == MovieListLoadStatus.success)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${viewModel.movies.length}편',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              Expanded(
                child: switch (viewModel.status) {
                  MovieListLoadStatus.idle ||
                  MovieListLoadStatus.loading => const MovieListLoading(),
                  MovieListLoadStatus.error => MovieListError(
                    onRetry: () =>
                        context.read<MovieListViewModel>().loadInitial(),
                  ),
                  MovieListLoadStatus.empty => const MovieListEmpty(),
                  MovieListLoadStatus.success => MovieGrid(
                    movies: viewModel.movies,
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
