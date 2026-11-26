import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/genre_chips.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_states.dart';
import '../widgets/movie_page_footer.dart';

// 9주차: 5주차의 Discover 최대 30개 수집 대신 PagedMoviesViewModel로 첫 page만 표시하고,
// 카드 목록 아래 footer의 "더 보기"로 다음 page를 이어서 불러옵니다.
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  // 장르 칩과 카드의 장르 이름 표시에 쓰는 Genre API 결과 (5주차 기능 유지)
  List<TmdbGenreDto> _genres = const [];
  int? _selectedGenreId;

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await context.read<TmdbMovieService>().fetchGenres();
      if (mounted) setState(() => _genres = genres);
    } catch (_) {
      // 장르 목록이 실패해도 "전체" 목록은 그대로 볼 수 있습니다.
    }
  }

  // 장르를 바꾸면 이전 목록을 비우고 첫 page부터 다시 불러옵니다.
  // generation이 올라가므로 이전 장르의 늦은 응답은 섞이지 않습니다.
  void _selectGenre(int? genreId) {
    setState(() => _selectedGenreId = genreId);
    context.read<PagedMoviesViewModel>().loadInitial(genreId: genreId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          IconButton(
            onPressed: () => context.push('/movies/search'),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: Consumer<PagedMoviesViewModel>(
        builder: (context, vm, _) {
          return Column(
            children: [
              GenreChips(
                genres: _genres,
                selectedId: _selectedGenreId,
                // 첫 page 요청 중에는 null을 넘겨 장르 변경을 막는다
                onSelected: vm.phase == LoadPhase.loading ? null : _selectGenre,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: switch (vm.phase) {
                  LoadPhase.idle ||
                  LoadPhase.loading => const MovieListLoading(),
                  LoadPhase.error => MovieListError(
                    message: vm.errorMessage,
                    onRetry: () => vm.loadInitial(genreId: _selectedGenreId),
                  ),
                  LoadPhase.empty => const MovieListEmpty(),
                  LoadPhase.ready => MovieGrid(
                    movies: vm.movies,
                    genres: _genres,
                    footer: MoviePageFooter(vm: vm),
                  ),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
