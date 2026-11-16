import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/safe_notify.dart';
import '../data/models/favorite_list_item.dart';
import '../data/models/favorite_response_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_phase.dart';

// 내 즐겨찾기 화면 상태 — /my/favorites Route에서 ValueKey(email:generation)와 함께 생성
// - 목록 조회(GET /v8/favorites) 실패 → error (전체)
// - 영화 정보(TMDB) 한 건 실패 → 그 카드만 placeholder (목록은 유지)
// - 응답 도착 시 세션(SessionGuard)·요청 순번(_refreshGeneration)·dispose를 확인한 뒤에만 반영
// - 세션 만료(AUTH401_2/3/4)는 AuthInterceptor → AuthViewModel이 전역 처리. 여기서는 로그아웃하지 않음
class FavoritesViewModel extends ChangeNotifier with SafeNotify {
  FavoritesViewModel({
    required this.favoriteApi,
    required this.tmdbApi,
    required this.sessionGuard,
    required this.accountId,
    this.enrichmentConcurrency = 5,
  });

  final FavoriteApiService favoriteApi;
  final TmdbMovieService tmdbApi;
  final SessionGuard sessionGuard;
  final String accountId; // /v8/members/me로 확인한 email
  final int enrichmentConcurrency;

  static const _movieErrorMessage = '영화 정보를 불러오지 못했습니다.';

  LoadPhase phase = LoadPhase.idle;
  List<FavoriteListItem> items = const [];
  String? errorMessage;
  int _refreshGeneration = 0; // refresh가 겹치면 마지막 요청만 반영
  final Set<int> _retryingMovieIds = {}; // 카드별 재조회 중인 movieId

  bool get hasPartialFailure => items.any((item) => !item.hasMovie);
  bool isRetrying(int movieId) => _retryingMovieIds.contains(movieId);

  bool _isCurrent(int sessionGeneration, int refreshGeneration) =>
      sessionGuard.isCurrent(sessionGeneration, accountId) &&
      refreshGeneration == _refreshGeneration &&
      !isDisposed;

  // 세션 확인 → 즐겨찾기 목록 조회 → TMDB 영화 정보 보충(Map) → 상태 결정
  Future<void> refresh() async {
    final sessionGeneration = sessionGuard.generation;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) {
      return;
    }
    final refreshGeneration = ++_refreshGeneration;
    _retryingMovieIds.clear();
    phase = LoadPhase.loading; // 기존 items는 유지 → 상세에서 돌아왔을 때 목록이 깜빡이지 않음
    errorMessage = null;
    notifyIfAlive();
    try {
      final favorites = await favoriteApi.fetchMyFavorites();
      if (!_isCurrent(sessionGeneration, refreshGeneration)) return;

      // movieId → 영화 정보. 실패한 영화는 key가 없음(null)
      final movies = await tmdbApi.fetchMovieDetails(
        favorites.map((favorite) => favorite.movieId).toList(),
        concurrency: enrichmentConcurrency,
      );
      if (!_isCurrent(sessionGeneration, refreshGeneration)) return;

      items = [
        for (final favorite in favorites) _itemFor(favorite, movies),
      ];
      phase = items.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } catch (error) {
      if (!_isCurrent(sessionGeneration, refreshGeneration)) return;
      if (error is DioException &&
          classifyApiError(error) == ApiErrorKind.sessionExpired) {
        return; // 전역 만료 처리 → 로그인 화면으로 이동하므로 문구 없음
      }
      // 네트워크 실패 등 — 로그아웃하지 않고 다시 시도 안내
      items = const [];
      phase = LoadPhase.error;
      errorMessage = '내 즐겨찾기 목록을 불러오지 못했습니다.';
    } finally {
      if (_isCurrent(sessionGeneration, refreshGeneration)) notifyIfAlive();
    }
  }

  // 영화 정보를 못 가져온 카드 하나만 다시 조회 (TMDB 공개 API — 세션 정리와 무관)
  Future<void> retryMovie(int movieId) async {
    final sessionGeneration = sessionGuard.generation;
    final refreshGeneration = _refreshGeneration;
    if (!_isCurrent(sessionGeneration, refreshGeneration)) return;
    if (!_retryingMovieIds.add(movieId)) return; // 이미 재조회 중
    notifyIfAlive();

    final movies = await tmdbApi.fetchMovieDetails([movieId]);
    if (!_isCurrent(sessionGeneration, refreshGeneration)) return;
    _retryingMovieIds.remove(movieId);
    items = [
      for (final item in items)
        item.favorite.movieId == movieId && !item.hasMovie
            ? _itemFor(item.favorite, movies)
            : item,
    ];
    notifyIfAlive();
  }

  static FavoriteListItem _itemFor(
    FavoriteResponseDto favorite,
    Map<int, TmdbMovieDto> movies,
  ) {
    final movie = movies[favorite.movieId];
    return FavoriteListItem(
      favorite: favorite,
      movie: movie,
      errorMessage: movie == null ? _movieErrorMessage : null,
    );
  }
}
