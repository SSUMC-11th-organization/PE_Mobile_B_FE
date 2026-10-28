import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/movie_home_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/hero_movie_card.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_list_states.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'MovieLog',
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      body: Consumer<MovieHomeViewModel>(
        builder: (context, viewModel, child) {
          return switch (viewModel.status) {
            MovieHomeLoadStatus.idle ||
            MovieHomeLoadStatus.loading => const MovieListLoading(),
            MovieHomeLoadStatus.error => MovieListError(
              message: viewModel.message,
              onRetry: viewModel.loadPopular,
            ),
            MovieHomeLoadStatus.empty => const MovieListEmpty(),
            MovieHomeLoadStatus.success => _HomeContent(
              movies: viewModel.popularMovies,
            ),
          };
        },
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.movies});

  // ViewModel이 Popular 결과에서 앞 5개만 담아 둔 목록
  final List<TmdbMovieDto> movies;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('오늘은 어떤\n영화를 볼까요?', style: AppTextStyles.titleLarge),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: HeroMovieCard(movie: movies.first),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('인기 영화', style: AppTextStyles.titleMedium),
              TextButton(
                onPressed: () => context.go('/movies'),
                child: const Text(
                  '전체보기 >',
                  style: TextStyle(color: AppColors.violet),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: movies.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 130,
                child: MovieCard(movie: movies[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}
