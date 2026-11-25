import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/map_bounded.dart';
import '../core/utils/safe_notify.dart';
import '../data/models/favorite_list_item.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_phase.dart';

class FavoritesViewModel extends ChangeNotifier with SafeNotify {
  FavoritesViewModel({
    required this.favoriteApi,
    required this.tmdbApi,
    required this.sessionGuard,
    required this.accountId,
    this.enrichmentConcurrency = 5,
    this.onSessionExpired,
  });

  final FavoriteApiService favoriteApi;
  final TmdbMovieService tmdbApi;
  final SessionGuard sessionGuard;
  final String accountId;
  final int enrichmentConcurrency;
  // 만료·무효 토큰(AUTH401_2/3/4)이면 8주차처럼 AuthViewModel.expireSession으로 세션을 정리합니다.
  final Future<void> Function()? onSessionExpired;

  LoadPhase phase = LoadPhase.idle;
  List<FavoriteListItem> items = const [];
  String? errorMessage;
  int _refreshGeneration = 0;

  // 즐겨찾기 목록을 다시 조회하고 TMDB 영화 정보를 최대 5개씩 보충합니다.
  Future<void> refresh() async {
    final sessionGeneration = sessionGuard.generation;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) {
      return;
    }
    final refreshGeneration = ++_refreshGeneration;
    phase = LoadPhase.loading;
    errorMessage = null;
    notifyIfAlive();
    try {
      final favorites = await favoriteApi.fetchMyFavorites();
      if (!sessionGuard.isCurrent(sessionGeneration, accountId) ||
          refreshGeneration != _refreshGeneration ||
          isDisposed) {
        return;
      }
      final enriched = await mapBounded(favorites, enrichmentConcurrency, (
        favorite,
      ) async {
        try {
          final movie = await tmdbApi.fetchMovieDetails(favorite.movieId);
          return FavoriteListItem(favorite: favorite, movie: movie);
        } catch (_) {
          return FavoriteListItem(
            favorite: favorite,
            errorMessage: '영화 정보를 불러오지 못했습니다.',
          );
        }
      });
      if (!sessionGuard.isCurrent(sessionGeneration, accountId) ||
          refreshGeneration != _refreshGeneration ||
          isDisposed) {
        return;
      }
      items = enriched;
      phase = items.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } catch (error) {
      if (!sessionGuard.isCurrent(sessionGeneration, accountId) ||
          refreshGeneration != _refreshGeneration ||
          isDisposed) {
        return;
      }
      phase = LoadPhase.error;
      errorMessage = '내 즐겨찾기 목록을 불러오지 못했습니다.';
      // TMDB 보충 실패는 카드별로 처리하므로 여기 오는 401은 MovieLog 즐겨찾기 조회의 401입니다.
      // 네트워크 실패·403은 로그아웃하지 않고 오류 화면만 보여 줍니다.
      if (error is DioException && isSessionExpiredCode(apiErrorCode(error))) {
        await onSessionExpired?.call();
        return;
      }
    } finally {
      if (sessionGuard.isCurrent(sessionGeneration, accountId) &&
          refreshGeneration == _refreshGeneration &&
          !isDisposed) {
        notifyIfAlive();
      }
    }
  }
}
