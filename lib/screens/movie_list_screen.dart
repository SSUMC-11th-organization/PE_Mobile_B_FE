import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../theme/app_colors.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_list_states.dart';
import '../widgets/paged_movie_grid.dart';

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  Future<void> _openGenreSheet(
    BuildContext context,
    PagedMoviesViewModel viewModel,
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
      viewModel.loadInitial(genreId: genreId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화 목록',
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '영화 검색',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/movies/search'),
          ),
          Consumer<PagedMoviesViewModel>(
            builder: (context, viewModel, child) => IconButton(
              tooltip: '장르 선택',
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
            Consumer<PagedMoviesViewModel>(
              builder: (context, viewModel, child) => GenreFilterChips(
                genres: viewModel.genres,
                selectedGenreId: viewModel.selectedGenreId,
                onSelected: (genreId) {
                  if (genreId == viewModel.selectedGenreId) return;
                  viewModel.loadInitial(genreId: genreId);
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Consumer<PagedMoviesViewModel>(
                builder: (context, viewModel, child) {
                  return switch (viewModel.phase) {
                    LoadPhase.idle ||
                    LoadPhase.loading => const MovieListLoading(),
                    LoadPhase.error => MovieListError(
                        message: viewModel.errorMessage ?? '영화를 불러오지 못했어요.',
                        onRetry: viewModel.retry,
                      ),
                    LoadPhase.empty => const MovieListEmpty(
                        message: '해당 장르의 영화가 없어요.',
                      ),
                    LoadPhase.ready => PagedMovieGrid(viewModel: viewModel),
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
    required this.onSelected,
  });

  final List<TmdbGenreDto> genres;
  final int? selectedGenreId;
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
            onSelected: (_) => onSelected(item.id),
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
