import 'package:flutter/foundation.dart';

import '../core/utils/safe_notify.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/models/tmdb_movie_page_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_phase.dart';

// 영화 목록(장르별 Discover) 한 page씩 — "더 보기"로 다음 page를 아래에 추가
// 검색 화면도 같은 클래스를 별도 인스턴스로 사용할 예정 (조건 record의 query)
// - 처음 로딩(phase)과 다음 page 로딩(isLoadingMore)을 구분
// - 조건이 바뀌면 _requestGeneration을 올려, 늦게 온 응답·오류·finally는 요청 시점 값이 같을 때만 반영
// - TMDB 공개 API만 호출 (MovieLog JWT·세션과 무관) → 어떤 오류에서도 로그아웃·세션 정리를 하지 않음
class PagedMoviesViewModel extends ChangeNotifier with SafeNotify {
  PagedMoviesViewModel({required this.tmdbApi});

  final TmdbMovieService tmdbApi;

  LoadPhase phase = LoadPhase.idle;
  final List<TmdbMovieDto> movies = [];
  int nextPage = 1; // 다음에 요청할 page — 성공 응답을 반영할 때만 올림
  int totalPages = 1; // 서버 total_pages와 TMDB 최대 500 중 작은 값
  bool isLoadingMore = false;
  String? errorMessage; // 첫 page 실패 (목록 전체 오류)
  String? loadMoreError; // 다음 page 실패 (기존 목록 유지, 하단에 표시)
  int _requestGeneration = 0;

  // 현재 조건 — 장르와 검색어를 함께 보관
  ({int? genreId, String query}) _condition = (genreId: null, query: '');
  ({int? genreId, String query}) get condition => _condition;

  bool get hasMore => nextPage <= totalPages;

  // 조건 변경·처음 진입·전체 재시도 — 목록·page·추가 로딩 상태·오류를 모두 초기화하고 첫 page 요청
  Future<void> loadInitial({int? genreId, String query = ''}) async {
    if (isDisposed) return;
    _condition = (genreId: genreId, query: query.trim());
    final condition = _condition;
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
      final page = await _fetchPage(1, condition);
      if (generation != _requestGeneration || isDisposed) return;
      _applyFirstPage(page);
    } catch (error) {
      if (generation != _requestGeneration || isDisposed) return;
      phase = LoadPhase.error;
      errorMessage = error is TmdbApiException
          ? error.message
          : (condition.query.isEmpty
              ? '영화 목록을 불러오지 못했습니다.'
              : '검색 결과를 불러오지 못했습니다.');
    } finally {
      if (generation == _requestGeneration && !isDisposed) notifyIfAlive();
    }
  }

  // 현재 조건 그대로 처음부터 다시 (첫 page 오류 화면의 다시 시도)
  Future<void> retry() =>
      loadInitial(genreId: _condition.genreId, query: _condition.query);

  // 다음 page — 실패해도 nextPage를 올리지 않아 같은 page를 다시 요청
  Future<void> loadNextPage() async {
    if (isDisposed || isLoadingMore || !hasMore || phase != LoadPhase.ready) {
      return;
    }
    final generation = _requestGeneration;
    final condition = _condition;
    final pageToLoad = nextPage;
    isLoadingMore = true;
    loadMoreError = null;
    notifyIfAlive();
    try {
      final page = await _fetchPage(pageToLoad, condition);
      if (generation != _requestGeneration || isDisposed) return;
      _appendPage(page);
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

  Future<TmdbMoviePageDto> _fetchPage(
    int page,
    ({int? genreId, String query}) condition,
  ) async {
    // 검색(query)은 다음 단계에서 연결 — 지금은 장르별 Discover만
    final result =
        await tmdbApi.fetchMoviePage(page: page, genreId: condition.genreId);
    if (result.page != page || result.totalPages < 0) {
      throw const FormatException('TMDB page metadata is inconsistent.');
    }
    return result;
  }

  void _applyFirstPage(TmdbMoviePageDto page) {
    movies
      ..clear()
      ..addAll(_dedupe(page.results));
    _applyPageInfo(page);
    phase = movies.isEmpty ? LoadPhase.empty : LoadPhase.ready;
  }

  void _appendPage(TmdbMoviePageDto page) {
    movies.addAll(_dedupe(page.results));
    _applyPageInfo(page);
  }

  void _applyPageInfo(TmdbMoviePageDto page) {
    totalPages = page.totalPages > TmdbMovieService.maxPage
        ? TmdbMovieService.maxPage
        : page.totalPages;
    nextPage = page.page + 1; // 성공 응답을 반영할 때만 증가
  }

  // TMDB는 page가 바뀌어도 같은 영화가 다시 올 수 있음 → 이미 가진 movieId는 제외
  List<TmdbMovieDto> _dedupe(List<TmdbMovieDto> incoming) {
    final seen = movies.map((movie) => movie.id).toSet();
    return incoming.where((movie) => seen.add(movie.id)).toList(growable: false);
  }
}
