import 'package:flutter/material.dart';

import '../data/mock_movies.dart';
import '../models/movie.dart';
import '../services/fake_movie_service.dart';
import '../services/genre_preference.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';

// 영화 목록 탭 — 장르 필터 Chip + 비동기 목록 로드(Loading/Empty/Error/Success)
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  static const _movieService = FakeMovieService();
  final _genrePreference = GenrePreference();

  late Future<List<Movie>> _moviesFuture;
  String? selectedGenre; // null이면 '전체'

  // mockMovies는 동기 상수라 로딩 상태와 무관하게 즉시 Chip 목록을 만들 수 있음
  final List<String> _genres =
      mockMovies.map((movie) => movie.genre).toSet().toList();

  @override
  void initState() {
    super.initState();
    _moviesFuture = _movieService.fetchMovies();
    _restoreSelectedGenre();
  }

  Future<void> _restoreSelectedGenre() async {
    final saved = await _genrePreference.read();
    if (!mounted) return;
    setState(() {
      selectedGenre = saved == GenrePreference.allGenresLabel ? null : saved;
    });
  }

  void _retry() {
    setState(() {
      _moviesFuture = _movieService.fetchMovies();
    });
  }

  Future<void> _onGenreSelected(String? genre) async {
    setState(() {
      selectedGenre = genre;
    });
    await _genrePreference.save(genre ?? GenrePreference.allGenresLabel);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  _buildGenreChip(label: '전체', genre: null),
                  for (final genre in _genres)
                    _buildGenreChip(label: genre, genre: genre),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Movie>>(
                future: _moviesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const MovieListLoading();
                  }

                  if (snapshot.hasError) {
                    return MovieListError(onRetry: _retry);
                  }

                  final movies = snapshot.data ?? const <Movie>[];
                  final filtered = selectedGenre == null
                      ? movies
                      : movies.where((m) => m.genre == selectedGenre).toList();

                  if (filtered.isEmpty) {
                    return const MovieListEmpty();
                  }

                  return MovieGrid(movies: filtered);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreChip({required String label, required String? genre}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selectedGenre == genre,
        onSelected: (_) => _onGenreSelected(genre),
      ),
    );
  }
}
