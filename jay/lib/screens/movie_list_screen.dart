import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jay/widgets/common_app_bar.dart';
import 'package:jay/widgets/genre_chips.dart';
import 'package:jay/services/fake_movie_service.dart';
import 'package:jay/services/genre_preference.dart';
import 'package:jay/widgets/mock_movie.dart';
import 'package:jay/widgets/movie_grid.dart';
import 'package:jay/widgets/movie_list_states.dart';

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  final _movieService = const FakeMovieService();
  final _genrePreference = GenrePreference();

  String selectedGenre = '전체';
  MovieLoadMode _loadMode = MovieLoadMode.success;
  late Future<List<Movie>> _moviesFuture;

  @override
  void initState() {
    super.initState();
    // build가 아닌 initState에서 한 번만 생성 → 필터를 바꿔도 Loading이 반복되지 않음
    _moviesFuture = _movieService.fetchMovies(mode: _loadMode);
    _restoreSelectedGenre();
  }

  Future<void> _restoreSelectedGenre() async {
    final savedGenre = await _genrePreference.read();
    // await 하는 사이 다른 탭으로 이동해 화면이 사라졌을 수 있음
    if (!mounted) return;
    setState(() {
      selectedGenre = savedGenre;
    });
  }

  Future<void> _selectGenre(String genre) async {
    setState(() {
      selectedGenre = genre;
    });
    await _genrePreference.save(genre);
  }

  // 재시도·모드 변경처럼 작업을 다시 시작해야 할 때만 새 Future를 할당한다
  void _reload({MovieLoadMode mode = MovieLoadMode.success}) {
    setState(() {
      _loadMode = mode;
      _moviesFuture = _movieService.fetchMovies(mode: mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          // 상태별 화면 확인용 (디버그 빌드에서만 표시)
          if (kDebugMode)
            PopupMenuButton<MovieLoadMode>(
              icon: const Icon(Icons.bug_report_outlined),
              initialValue: _loadMode,
              onSelected: (mode) => _reload(mode: mode),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: MovieLoadMode.success,
                  child: Text('Success'),
                ),
                PopupMenuItem(value: MovieLoadMode.empty, child: Text('Empty')),
                PopupMenuItem(
                  value: MovieLoadMode.failure,
                  child: Text('Error'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          GenreChips(
            genres: genres,
            selected: selectedGenre,
            onSelected: _selectGenre,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Movie>>(
              future: _moviesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const MovieListLoading();
                }

                // 오류를 빈 목록보다 먼저 확인해야 Error가 Empty로 보이지 않음
                if (snapshot.hasError) {
                  // 재시도는 서버가 복구된 상황을 가정해 success 모드로 다시 요청
                  return MovieListError(onRetry: _reload);
                }

                final loadedMovies = snapshot.data ?? const <Movie>[];
                // 전역 movies가 아니라 서비스에서 받아온 목록을 필터링
                final filteredMovies = selectedGenre == '전체'
                    ? loadedMovies
                    : loadedMovies
                          .where((movie) => movie.genre == selectedGenre)
                          .toList();

                if (filteredMovies.isEmpty) {
                  return const MovieListEmpty();
                }

                return MovieGrid(movies: filteredMovies);
              },
            ),
          ),
        ],
      ),
    );
  }
}
