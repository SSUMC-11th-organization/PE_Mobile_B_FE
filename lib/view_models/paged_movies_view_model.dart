import 'package:flutter/foundation.dart';

import '../core/utils/safe_notify.dart';
import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/models/tmdb_movie_page_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_phase.dart';

/// 영화 목록(Discover)과 검색(Search)이 각각 별도 인스턴스로 사용합니다.
class PagedMoviesViewModel extends ChangeNotifier with SafeNotify {
  PagedMoviesViewModel(this._tmdbApi);

  final TmdbMovieService _tmdbApi;

  static const maxTmdbPage = 500;

  LoadPhase phase = LoadPhase.idle;
  final List<TmdbMovieDto> movies = [];
  List<TmdbGenreDto> genres = const [];
  int nextPage = 1;
  int totalPages = 1;
  bool isLoadingMore = false;
  String? errorMessage;
  String? loadMoreError;
  int _requestGeneration = 0;
  ({int? genreId, String query}) _condition = (genreId: null, query: '');

  int? get selectedGenreId => _condition.genreId;
  bool get hasMore => nextPage <= totalPages;

  /// 장르 칩은 부가 기능이라 실패해도 목록은 그대로 보여 줍니다.
  Future<void> loadGenres() async {
    try {
      genres = await _tmdbApi.fetchGenres();
      notifyIfAlive();
    } catch (_) {}
  }

  /// 조건이 바뀌면 이전 목록·page·추가 로딩 상태를 모두 초기화합니다.
  Future<void> loadInitial({int? genreId, String query = ''}) async {
    if (isDisposed) return;
    _condition = (genreId: genreId, query: query.trim());
    final generation = ++_requestGeneration;
    phase = LoadPhase.loading;
    errorMessage = null;
    loadMoreError = null;
    isLoadingMore = false;
    movies.clear();
    nextPage = 1;
    totalPages = 1;
    notifyIfAlive();
    try {
      final page = await _fetchPage(1);
      if (generation != _requestGeneration || isDisposed) return;
      _append(page);
      phase = movies.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } catch (_) {
      if (generation != _requestGeneration || isDisposed) return;
      phase = LoadPhase.error;
      errorMessage = _condition.query.isEmpty
          ? '영화 목록을 불러오지 못했습니다.'
          : '검색 결과를 불러오지 못했습니다.';
    }
    notifyIfAlive();
  }

  Future<void> retry() {
    if (genres.isEmpty && _condition.query.isEmpty) loadGenres();
    return loadInitial(genreId: _condition.genreId, query: _condition.query);
  }

  /// 성공했을 때만 nextPage를 올리므로 실패하면 같은 page를 다시 요청합니다.
  Future<void> loadNextPage() async {
    if (isDisposed || isLoadingMore || !hasMore || phase != LoadPhase.ready) {
      return;
    }
    final generation = _requestGeneration;
    isLoadingMore = true;
    loadMoreError = null;
    notifyIfAlive();
    try {
      final page = await _fetchPage(nextPage);
      if (generation != _requestGeneration || isDisposed) return;
      _append(page);
    } catch (_) {
      if (generation != _requestGeneration || isDisposed) return;
      loadMoreError = '다음 페이지를 불러오지 못했습니다.';
    } finally {
      if (generation == _requestGeneration && !isDisposed) {
        isLoadingMore = false;
        notifyIfAlive();
      }
    }
  }

  Future<TmdbMoviePageDto> _fetchPage(int page) async {
    final result = _condition.query.isNotEmpty
        ? await _tmdbApi.searchMovies(page: page, query: _condition.query)
        : await _tmdbApi.discoverMovies(
            page: page,
            genreId: _condition.genreId,
          );
    if (result.page != page || result.totalPages < 0) {
      throw const FormatException('TMDB page metadata is inconsistent.');
    }
    return result;
  }

  void _append(TmdbMoviePageDto page) {
    // TMDB는 page가 달라도 같은 영화를 다시 내려줄 수 있습니다.
    final seen = movies.map((movie) => movie.id).toSet();
    movies.addAll(page.results.where((movie) => seen.add(movie.id)).toList());
    totalPages = page.totalPages.clamp(0, maxTmdbPage);
    nextPage = page.page + 1;
  }
}
