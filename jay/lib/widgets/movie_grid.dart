import 'package:flutter/material.dart';

import 'mock_movie.dart';
import 'movie_card.dart';

class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies});

  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final item = movies[index];
        return MovieCard(movie: item);
      },
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.55,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
