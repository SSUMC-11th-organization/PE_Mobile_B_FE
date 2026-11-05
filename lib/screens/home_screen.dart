import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/movie_home_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_list_states.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: const CommonAppBar(title: 'MovieLog', centerTitle: true),
        backgroundColor: AppColors.warmWhite,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('지금 인기 있는 영화', style: AppTextStyles.titleMedium),
                ),
                const SizedBox(height: 16),
                const PopularMovieList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PopularMovieList extends StatelessWidget {
  const PopularMovieList({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Consumer<MovieHomeViewModel>(
        builder: (context, viewModel, child) {
          switch (viewModel.status) {
            case MovieHomeLoadStatus.idle:
            case MovieHomeLoadStatus.loading:
              return const MovieListLoading();
            case MovieHomeLoadStatus.error:
              return MovieListError(
                message: viewModel.message ?? '인기 영화를 불러오지 못했어요.',
                onRetry: () =>
                    context.read<MovieHomeViewModel>().loadPopular(),
              );
            case MovieHomeLoadStatus.empty:
              return const MovieListEmpty(message: '인기 영화가 없어요.');
            case MovieHomeLoadStatus.success:
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: viewModel.popularMovies.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 140,
                    child: MovieCard(movie: viewModel.popularMovies[index]),
                  );
                },
              );
          }
        },
      ),
    );
  }
}
