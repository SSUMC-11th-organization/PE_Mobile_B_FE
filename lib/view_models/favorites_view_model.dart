import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/map_bounded.dart';
import '../core/utils/safe_notify.dart';
import '../data/models/favorite_list_item.dart';
import '../data/models/favorite_response_dto.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_phase.dart';

class FavoritesViewModel extends ChangeNotifier with SafeNotify {
  FavoritesViewModel({
    required this.favoriteApi,
    required this.tmdbApi,
    required this.sessionGuard,
    required this.accountId,
    required this.onSessionExpired,
  });

  final FavoriteApiService favoriteApi;
  final TmdbMovieService tmdbApi;
  final SessionGuard sessionGuard;
  final String accountId;
  final Future<void> Function() onSessionExpired;

  LoadPhase phase = LoadPhase.idle;
  List<FavoriteListItem> items = const [];
  String? errorMessage;
  int _refreshGeneration = 0;

  /// TMDB 한 건의 실패는 그 카드의 movie == null로 바꿉니다.
  Future<FavoriteListItem> _enrich(FavoriteResponseDto favorite) async {
    try {
      final movie = await tmdbApi.fetchMovieDetail(favorite.movieId);
      return FavoriteListItem(favorite: favorite, movie: movie);
    } catch (_) {
      return FavoriteListItem(favorite: favorite);
    }
  }

  Future<void> refresh() async {
    final session = sessionGuard.generation;
    if (isDisposed || !sessionGuard.isCurrent(session, accountId)) return;
    final request = ++_refreshGeneration;
    bool isStale() =>
        isDisposed ||
        request != _refreshGeneration ||
        !sessionGuard.isCurrent(session, accountId);

    // 이미 목록이 있으면 지우지 않고 뒤에서 갱신합니다.
    if (phase != LoadPhase.ready) phase = LoadPhase.loading;
    errorMessage = null;
    notifyIfAlive();
    try {
      final favorites = await favoriteApi.fetchMyFavorites();
      if (isStale()) return;
      final enriched = await mapBounded(favorites, 5, _enrich);
      if (isStale()) return;
      items = enriched;
      phase = items.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } catch (error) {
      if (isStale()) return;
      if (error is DioException && isSessionExpiredCode(apiErrorCode(error))) {
        await onSessionExpired();
        return;
      }
      items = const [];
      phase = LoadPhase.error;
      errorMessage = '내 즐겨찾기 목록을 불러오지 못했습니다.';
    }
    notifyIfAlive();
  }

  /// 실패한 카드 한 장만 다시 조회합니다.
  Future<void> retryMovie(int movieId) async {
    final session = sessionGuard.generation;
    final request = _refreshGeneration;
    final index = items.indexWhere((item) => item.favorite.movieId == movieId);
    if (index < 0) return;
    final updated = await _enrich(items[index].favorite);
    if (isDisposed ||
        request != _refreshGeneration ||
        !sessionGuard.isCurrent(session, accountId)) {
      return;
    }
    items = [
      for (final item in items)
        item.favorite.movieId == movieId ? updated : item,
    ];
    notifyIfAlive();
  }
}
