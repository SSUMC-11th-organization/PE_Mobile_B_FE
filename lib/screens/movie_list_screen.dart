import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import '../services/genre_preference.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/movie_page_footer.dart';

// 영화 목록 탭 — TMDB 장르 Chip + Discover 첫 page, "더 보기"로 다음 page를 아래에 추가
// 영화 목록 상태는 PagedMoviesViewModel, 장르 Chip 목록·저장된 장르는 이 화면이 관리
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  final _genrePreference = GenrePreference();
  List<TmdbGenreDto> _genres = const [];

  @override
  void initState() {
    super.initState();
    // build가 아니라 진입 시 한 번 — 장르 목록·저장된 장르를 읽은 뒤 첫 page 요청
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  Future<void> _start() async {
    final vm = context.read<PagedMoviesViewModel>();
    final service = context.read<TmdbMovieService>();
    // 장르 목록·저장값 읽기 실패는 목록 표시에 영향이 없도록 무시 ('전체' Chip만 표시)
    final (genres, savedGenreId) = await (
      service.fetchGenres().catchError((Object _) => <TmdbGenreDto>[]),
      _readSavedGenreId(),
    ).wait;
    if (!mounted) return;
    setState(() => _genres = genres);
    // 저장된 장르가 현재 장르 목록에 없으면 '전체'
    final genreId =
        genres.any((genre) => genre.id == savedGenreId) ? savedGenreId : null;
    await vm.loadInitial(genreId: genreId);
  }

  Future<int?> _readSavedGenreId() async {
    try {
      return await _genrePreference.read();
    } catch (_) {
      return null;
    }
  }

  // 장르 변경 → 이전 목록을 비우고 첫 page부터 (로딩 중에도 변경 가능 — 늦은 응답은 generation으로 버림)
  void _selectGenre(PagedMoviesViewModel vm, int? genreId) {
    if (genreId == vm.condition.genreId && vm.phase == LoadPhase.ready) return;
    _genrePreference.save(genreId).catchError((Object _) {});
    vm.loadInitial(genreId: genreId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          // 검색 화면은 탭 위에 push (뒤로가기로 목록 상태 그대로 복귀)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '영화 검색',
            onPressed: () => context.push('/movies/search'),
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<PagedMoviesViewModel>(
          builder: (context, vm, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 장르 필터 — 장르가 많아 가로 스크롤
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      _GenreChip(
                        label: '전체',
                        selected: vm.condition.genreId == null,
                        onSelected: () => _selectGenre(vm, null),
                      ),
                      for (final genre in _genres)
                        _GenreChip(
                          label: genre.name,
                          selected: vm.condition.genreId == genre.id,
                          onSelected: () => _selectGenre(vm, genre.id),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildBody(vm)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(PagedMoviesViewModel vm) {
    switch (vm.phase) {
      case LoadPhase.idle:
      case LoadPhase.loading:
        return const MovieListLoading();
      case LoadPhase.error:
        return MovieListError(message: vm.errorMessage, onRetry: vm.retry);
      case LoadPhase.empty:
        return const MovieListEmpty();
      case LoadPhase.ready:
        // 기존 카드 그리드 + 아래 footer (다음 page 로딩 중에도 기존 카드는 유지)
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.65,
                ),
                itemCount: vm.movies.length,
                itemBuilder: (context, index) =>
                    MovieCard(movie: vm.movies[index]),
              ),
            ),
            SliverToBoxAdapter(child: MoviePageFooter(vm: vm)),
          ],
        );
    }
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
