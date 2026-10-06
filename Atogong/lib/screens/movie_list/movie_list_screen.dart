import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/movie.dart'; // 실제 Movie 경로
import '../../services/fake_movie_service.dart';
import '../../services/genre_preference.dart';
import 'widgets/genre_chips.dart';
import 'widgets/movie_grid.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';

class _InitialData {
  const _InitialData({required this.movies, required this.savedGenre});
  final List<Movie> movies;
  final String savedGenre;
}

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  static const _genres = ['전체', '드라마', 'SF', '애니메이션', '스릴러'];

  // TODO(5주차): 유저별 평점 조회 API Service로 교체
  final _movieService = const FakeMovieService();
  final _genrePreference = GenrePreference();

  late Future<_InitialData> _future; // initState에서만 생성
  String _selectedGenre = '전체';
  MovieLoadMode _mode = MovieLoadMode.success; // 디버그용

  @override
  void initState() {
    super.initState();
    _future = _loadInitialData();
  }

  Future<_InitialData> _loadInitialData() async {
    final results = await Future.wait<Object>([
      _movieService.fetchMovies(mode: _mode),
      _genrePreference.read(),
    ]);
    final data = _InitialData(
      movies: results[0] as List<Movie>,
      savedGenre: results[1] as String,
    );
    if (mounted) {
      setState(() => _selectedGenre = data.savedGenre); // 저장된 장르 복원
    }
    return data;
  }

  void _retry() {
    setState(() {
      _future = _loadInitialData(); // 재시도할 때만 새 Future
    });
  }

  Future<void> _onGenreSelected(String genre) async {
    setState(() => _selectedGenre = genre);
    await _genrePreference.save(genre); // 마지막 선택 장르 저장
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '영화',
          style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (kDebugMode)
            PopupMenuButton<MovieLoadMode>(
              icon: const Icon(Icons.bug_report_outlined),
              onSelected: (mode) {
                _mode = mode;
                _retry();
              },
              itemBuilder: (_) => MovieLoadMode.values
                  .map((m) => PopupMenuItem(value: m, child: Text(m.name)))
                  .toList(),
            ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
        ],
      ),
      body: Column(
        children: [
          GenreChips(
            genres: _genres,
            selected: _selectedGenre,
            onSelected: _onGenreSelected,
          ),
          Expanded(
            child: FutureBuilder<_InitialData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const MovieListLoading();
                }
                if (snapshot.hasError) {
                  return MovieListError(onRetry: _retry);
                }

                final movies = snapshot.data?.movies ?? const <Movie>[];
                final filtered = _selectedGenre == '전체'
                    ? movies
                    : movies.where((m) => m.genre == _selectedGenre).toList();

                if (filtered.isEmpty) return const MovieListEmpty();
                return MovieGrid(movies: filtered);
              },
            ),
          ),
        ],
      ),
    );
  }
}
