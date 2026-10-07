import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../services/fake_movie_service.dart';
import '../services/genre_preference.dart';
import '../theme/app_colors.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_list_states.dart';

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  static const _all = '전체';

  // 서비스 인스턴스 (Mock 영화 서비스 & SharedPreferences 설정 저장소)
  final FakeMovieService _movieService = const FakeMovieService();
  final GenrePreference _genrePreference = GenrePreference();

  // 과제 인증(Loading/Empty/Error/Success) 테스트용 모드
  MovieLoadMode _currentMode = MovieLoadMode.success;

  // 비동기로 받아올 영화 목록을 담는 Future 변수
  // 주의: Future는 build()가 아니라 initState()에서 생성해야 반복 호출되지 않습니다!
  late Future<List<Movie>> _moviesFuture;

  // 현재 선택된 장르 (기본값: '전체')
  String _selectedGenre = _all;

  @override
  void initState() {
    super.initState();

    // 1. 화면이 처음 열릴 때 영화 데이터 요청 Future를 생성합니다.
    _moviesFuture = _movieService.fetchMovies(mode: _currentMode);

    // 2. 기기 로컬 저장소(SharedPreferences)에 저장된 마지막 선택 장르를 불러옵니다.
    _loadSavedGenre();
  }

  /// 저장된 장르를 비동기로 읽어와 화면에 반영합니다.
  Future<void> _loadSavedGenre() async {
    final savedGenre = await _genrePreference.read();

    // 비동기 작업(await)이 끝난 시점에 화면이 이미 닫혔을 수 있으므로
    // 반드시 mounted 상태인지 확인한 뒤 setState를 호출해야 에러가 발생하지 않습니다.
    if (!mounted) return;

    setState(() {
      _selectedGenre = savedGenre;
    });
  }

  /// 오류 발생 시 '다시 시도' 버튼을 누르면 호출되는 함수입니다.
  /// 새로운 Future를 할당하고 setState()를 호출해 화면을 다시 그리게 만듭니다.
  void _retry() {
    setState(() {
      // 재시도 시에는 성공 모드로 다시 호출하여 화면 복구를 확인합니다.
      _currentMode = MovieLoadMode.success;
      _moviesFuture = _movieService.fetchMovies(mode: _currentMode);
    });
  }

  /// 사용자가 장르를 변경했을 때 호출되는 함수입니다.
  void _onGenreSelected(String genre) {
    setState(() {
      _selectedGenre = genre;
    });
    // 선택한 장르를 로컬 저장소에 영구 저장합니다. (앱을 껐다 켜도 유지)
    _genrePreference.save(genre);
  }

  /// 장르 선택 바텀시트를 띄웁니다.
  Future<void> _openGenreSheet(
    BuildContext context,
    List<String> genres,
  ) async {
    final genre = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final g in genres)
              ListTile(
                title: Text(g),
                trailing: g == _selectedGenre
                    ? const Icon(Icons.check, color: AppColors.violet)
                    : null,
                onTap: () => Navigator.pop(sheetContext, g),
              ),
          ],
        ),
      ),
    );

    if (genre != null) {
      _onGenreSelected(genre);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 필터링에 사용할 전체 장르 목록
    final genres = [
      _all,
      ...{for (final movie in movies) movie.genre},
    ];

    return Scaffold(
      appBar: CommonAppBar(
        title: '영화 목록',
        centerTitle: true,
        actions: [
          // 스터디 인증 캡처용: 상태(성공, 빈목록, 오류)를 쉽게 변경할 수 있는 디버그 메뉴
          PopupMenuButton<MovieLoadMode>(
            tooltip: '테스트 모드 변경',
            icon: const Icon(Icons.tune),
            onSelected: (mode) {
              setState(() {
                _currentMode = mode;
                _moviesFuture = _movieService.fetchMovies(mode: _currentMode);
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: MovieLoadMode.success,
                child: Text('성공 (Success) 모드'),
              ),
              PopupMenuItem(
                value: MovieLoadMode.empty,
                child: Text('빈 목록 (Empty) 모드'),
              ),
              PopupMenuItem(
                value: MovieLoadMode.failure,
                child: Text('오류 (Error) 모드'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _openGenreSheet(context, genres),
          ),
        ],
      ),
      backgroundColor: AppColors.warmWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            // 상단 장르 필터 Chip 목록
            GenreFilterChips(
              genres: genres,
              selectedGenre: _selectedGenre,
              onSelected: _onGenreSelected,
            ),
            const SizedBox(height: 8),

            // 비동기 결과에 따라 Loading, Error, Empty, Success 화면을 보여주는 FutureBuilder
            Expanded(
              child: FutureBuilder<List<Movie>>(
                future: _moviesFuture,
                builder: (context, snapshot) {
                  // 1. Loading 상태: 데이터를 기다리는 중일 때
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const MovieListLoading();
                  }

                  // 2. Error 상태: 데이터를 불러오다 오류가 발생했을 때
                  if (snapshot.hasError) {
                    return MovieListError(onRetry: _retry);
                  }

                  // 3. 데이터 로드 성공 후
                  final loadedMovies = snapshot.data ?? const <Movie>[];

                  // 3-1. Empty 상태 (전체 데이터 자체가 비어 있는 경우)
                  if (loadedMovies.isEmpty) {
                    return const MovieListEmpty(
                      message: '불러올 영화가 없습니다.',
                    );
                  }

                  // 현재 선택된 장르로 영화 목록 필터링
                  final filteredMovies = _selectedGenre == _all
                      ? loadedMovies
                      : loadedMovies
                          .where((m) => m.genre == _selectedGenre)
                          .toList();

                  // 3-2. Empty 상태 (선택한 장르의 영화가 없는 경우)
                  if (filteredMovies.isEmpty) {
                    return const MovieListEmpty(
                      message: '해당 장르의 영화가 없습니다.',
                    );
                  }

                  // 4. Success 상태: 최종 영화 목록 그리드 렌더링
                  return MovieGrid(movies: filteredMovies);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GenreFilterChips extends StatelessWidget {
  const GenreFilterChips({
    super.key,
    required this.genres,
    required this.selectedGenre,
    required this.onSelected,
  });

  final List<String> genres;
  final String selectedGenre;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: genres.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = genres[index];
          final selected = genre == selectedGenre;
          return ChoiceChip(
            label: Text(genre),
            selected: selected,
            onSelected: (_) => onSelected(genre),
            selectedColor: AppColors.violet,
            labelStyle: TextStyle(
              color: selected ? AppColors.white : AppColors.black,
            ),
            backgroundColor: AppColors.lightGray,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide.none,
            ),
          );
        },
      ),
    );
  }
}

class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies});

  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: movies.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.65,
      ),
      itemBuilder: (context, index) => MovieCard(movie: movies[index]),
    );
  }
}
