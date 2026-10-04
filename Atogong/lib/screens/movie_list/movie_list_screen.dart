import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_movies.dart';
import 'widgets/genre_filter_sheet.dart';
import 'widgets/movie_grid.dart';

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key, required this.selectedGenres});

  final Set<String> selectedGenres;

  Future<void> _openFilter(BuildContext context) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GenreFilterSheet(initialSelected: selectedGenres),
    );
    if (result == null || !context.mounted) return;

    final location = Uri(
      path: '/movies',
      queryParameters: result.isEmpty ? null : {'genre': result.join(',')},
    ).toString();
    context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = selectedGenres.isEmpty
        ? movies
        : movies.where((m) => selectedGenres.contains(m.genre)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '영화',
          style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => _openFilter(context),
            icon: Badge(
              isLabelVisible: selectedGenres.isNotEmpty,
              label: Text('${selectedGenres.length}'),
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      body: MovieGrid(movies: filtered),
    );
  }
}
