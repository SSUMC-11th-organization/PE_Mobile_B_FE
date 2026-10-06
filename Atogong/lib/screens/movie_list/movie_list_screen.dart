import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/movie.dart';
import '../../services/fake_movie_service.dart';
import '../../services/genre_preference.dart';
import 'widgets/genre_filter_sheet.dart';
import 'widgets/movie_grid.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';

/// 초기 로드 결과: 영화 목록 + 저장된 장르
class _InitialData {
  const _InitialData({required this.movies, required this.savedGenres});
  final List<Movie> movies;
  final Set<String> savedGenres;
}

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key, required this.selectedGenres});

  final Set<String> selectedGenres;

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  final _movieService = const FakeMovieService();
  final _genrePreference = GenrePreference();

  late Future<_InitialData> _future; // build가 아닌 initState에서 생성
  late Set<String> _selectedGenres;
  MovieLoadMode _mode = MovieLoadMode.success; // 디버그용 상태 전환

  @override
  void initState() {
    super.initState();
    _selectedGenres = widget.selectedGenres;
    _future = _loadInitialData();
  }

  // 라우터 query parameter가 바뀌어 같은 화면이 갱신될 때 동기화
  @override
  void didUpdateWidget(MovieListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedGenres != oldWidget.selectedGenres) {
      _selectedGenres = widget.selectedGenres;
    }
  }

  Future<_InitialData> _loadInitialData() async {
    final results = await Future.wait<Object>([
      _movieService.fetchMovies(mode: _mode),
      _genrePreference.read(),
    ]);
    final data = _InitialData(
      movies: results[0] as List<Movie>,
      savedGenres: results[1] as Set<String>,
    );

    // URL에 장르가 없을 때만 저장된 장르로 복원 (await 뒤이므로 mounted 확인)
    if (mounted && widget.selectedGenres.isEmpty) {
      setState(() => _selectedGenres = data.savedGenres);
    }
    return data;
  }

  // 재시도할 때만 새 Future 생성
  void _retry() {
    setState(() {
      _future = _loadInitialData();
    });
  }

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GenreFilterSheet(initialSelected: _selectedGenres),
    );
    if (result == null || !mounted) return;

    setState(() => _selectedGenres = result);
    await _genrePreference.save(result); // 마지막 선택 장르 저장
    if (!mounted) return;

    final location = Uri(
      path: '/movies',
      queryParameters: result.isEmpty ? null : {'genre': result.join(',')},
    ).toString();
    context.go(location);
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
          IconButton(
            onPressed: _openFilter,
            icon: Badge(
              isLabelVisible: _selectedGenres.isNotEmpty,
              label: Text('${_selectedGenres.length}'),
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      body: FutureBuilder<_InitialData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MovieListLoading();
          }
          if (snapshot.hasError) {
            // 내부 Exception은 화면에 노출하지 않음
            return MovieListError(onRetry: _retry);
          }

          final data = snapshot.data;
          final movies = data?.movies ?? const <Movie>[];

          final filtered = _selectedGenres.isEmpty
              ? movies
              : movies.where((m) => _selectedGenres.contains(m.genre)).toList();

          if (filtered.isEmpty) {
            return const MovieListEmpty();
          }
          return MovieGrid(movies: filtered);
        },
      ),
    );
  }
}
