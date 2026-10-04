import 'package:flutter/material.dart';

import '../../data/mock_movies.dart';
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
      body: ListView(
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
            child: FeaturedBanner(movie: movies.first),
          ),
          const SizedBox(height: 32),
          const PopularMovieList(),
        ],
      ),
    );
  }
}
