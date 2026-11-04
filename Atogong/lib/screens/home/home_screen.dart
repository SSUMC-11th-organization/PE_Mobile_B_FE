import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../view_models/movie_home_view_model.dart';
import 'widgets/featured_banner.dart';
import 'widgets/popular_movie_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MovieLog',
          style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
        ),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      // 화면은 ViewModel 상태만 읽어서 그림. API 호출·파싱은 ViewModel/Service 책임
      body: Consumer<MovieHomeViewModel>(
        builder: (context, viewModel, _) {
          return switch (viewModel.status) {
            MovieHomeLoadStatus.idle || MovieHomeLoadStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            MovieHomeLoadStatus.error => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(viewModel.message ?? '인기 영화를 불러오지 못했어요.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        context.read<MovieHomeViewModel>().loadPopular(),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
            MovieHomeLoadStatus.empty => const Center(
              child: Text('표시할 인기 영화가 없어요.'),
            ),
            MovieHomeLoadStatus.success => ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '오늘은 어떤\n영화를 볼까요?',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FeaturedBanner(movie: viewModel.popularMovies.first),
                ),
                const SizedBox(height: 32),
                PopularMovieList(movies: viewModel.popularMovies),
              ],
            ),
          };
        },
      ),
    );
  }
}
