import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../view_models/movie_list_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_list_states.dart';

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  Future<void> _openGenreSheet(
    BuildContext context,
    MovieListViewModel viewModel,
  ) async {
    final genreId = await showModalBottomSheet<int?>(
      context: context,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('전체'),
              trailing: viewModel.selectedGenreId == null
                  ? const Icon(Icons.check, color: AppColors.violet)
                  : null,
              onTap: () => Navigator.pop(sheetContext, null),
            ),
            for (final genre in viewModel.genres)
              ListTile(
                title: Text(genre.name),
                trailing: genre.id == viewModel.selectedGenreId
                    ? const Icon(Icons.check, color: AppColors.violet)
                    : null,
                onTap: () => Navigator.pop(sheetContext, genre.id),
              ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    if (genreId != viewModel.selectedGenreId) {
      viewModel.selectGenre(genreId);
    }
  }

  Future<void> _openDebugSheet(
    BuildContext context,
    MovieListViewModel viewModel,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        void pick(VoidCallback action) {
          Navigator.pop(sheetContext);
          action();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('상태 테스트 (디버그 전용)'),
                subtitle: Text('화면에 상태를 강제로 띄웁니다.'),
              ),
              ListTile(
                leading: const Icon(Icons.hourglass_empty),
                title: const Text('Loading'),
                onTap: () => pick(
                  () => viewModel.simulate(MovieListLoadStatus.loading),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.movie_outlined),
                title: const Text('Empty'),
                onTap: () =>
                    pick(() => viewModel.simulate(MovieListLoadStatus.empty)),
              ),
              ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Error'),
                onTap: () =>
                    pick(() => viewModel.simulate(MovieListLoadStatus.error)),
              ),
              ListTile(
                leading: const Icon(Icons.refresh, color: AppColors.violet),
                title: const Text('실제 데이터로 복구'),
                onTap: () => pick(viewModel.retry),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화 목록',
        centerTitle: true,
        actions: [
          if (kDebugMode)
            Consumer<MovieListViewModel>(
              builder: (context, viewModel, child) => IconButton(
                tooltip: '상태 테스트',
                icon: const Icon(Icons.bug_report_outlined),
                onPressed: () => _openDebugSheet(context, viewModel),
              ),
            ),
          Consumer<MovieListViewModel>(
            builder: (context, viewModel, child) => IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _openGenreSheet(context, viewModel),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.warmWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Consumer<MovieListViewModel>(
              builder: (context, viewModel, child) => GenreFilterChips(
                genres: viewModel.genres,
                selectedGenreId: viewModel.selectedGenreId,
                enabled: !viewModel.isLoading,
                onSelected: (genreId) => viewModel.selectGenre(genreId),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Consumer<MovieListViewModel>(
                builder: (context, viewModel, child) {
                  return switch (viewModel.status) {
                    MovieListLoadStatus.idle ||
                    MovieListLoadStatus.loading => const MovieListLoading(),
                    MovieListLoadStatus.error => MovieListError(
                        message: viewModel.message ?? '영화를 불러오지 못했어요.',
                        onRetry: () =>
                            context.read<MovieListViewModel>().retry(),
                      ),
                    MovieListLoadStatus.empty => const MovieListEmpty(
                        message: '해당 장르의 영화가 없어요.',
                      ),
                    MovieListLoadStatus.success => MovieGrid(
                        movies: viewModel.movies,
                      ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GenreFilterChips extends StatelessWidget {
  const GenreFilterChips({
    super.key,
    required this.genres,
    required this.selectedGenreId,
    required this.enabled,
    required this.onSelected,
  });

  final List<TmdbGenreDto> genres;
  final int? selectedGenreId;
  final bool enabled;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <({int? id, String name})>[
      (id: null, name: '전체'),
      for (final genre in genres) (id: genre.id, name: genre.name),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = item.id == selectedGenreId;
          return ChoiceChip(
            label: Text(item.name),
            selected: selected,
            onSelected: enabled ? (_) => onSelected(item.id) : null,
            selectedColor: AppColors.violet,
            labelStyle: TextStyle(
              color: selected ? AppColors.white : AppColors.black,
            ),
            backgroundColor: AppColors.lightGray,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide.none,
            ),
          );
        },
      ),
    );
  }
}

class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies});

  final List<TmdbMovieDto> movies;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: movies.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.65,
      ),
      itemBuilder: (context, index) => MovieCard(movie: movies[index]),
    );
  }
}
