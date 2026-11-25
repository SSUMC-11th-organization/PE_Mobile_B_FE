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

/// 내 즐겨찾기 화면. 세션 확인 → 즐겨찾기 목록 조회 → TMDB 영화 정보 보충 → 상태 결정.
/// 목록 조회 전체 실패(error)와 영화 한 건의 정보만 못 가져온 경우(item.movie == null)를 구분
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
  // 보호 요청에서 만료·무효 토큰(AUTH401_2/3/4)을 받았을 때 호출. Route에서 AuthViewModel.expireSession을 연결
  final Future<void> Function()? onSessionExpired;

  LoadPhase phase = LoadPhase.idle;
  List<FavoriteListItem> items = const [];
  String? errorMessage;
  int _refreshGeneration = 0; // 연속으로 refresh했을 때 마지막 요청의 결과만 반영

  // 즐겨찾기 목록을 다시 조회하고 TMDB 영화 정보를 최대 5개씩 보충
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
        // 카드별 실패를 예외가 아닌 결과로 바꿔서, 한 건 실패가 목록 전체를 비우지 않게 함
        try {
          // 5주차에 만든 GET /movie/{id} 메서드를 그대로 재사용
          final movie = await tmdbApi.fetchMovieDetail(favorite.movieId);
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
      // 이전 계정에서 늦게 도착한 401이 현재 계정을 로그아웃시키지 않도록 세션부터 확인
      if (!sessionGuard.isCurrent(sessionGeneration, accountId) ||
          refreshGeneration != _refreshGeneration ||
          isDisposed) {
        return;
      }
      phase = LoadPhase.error;
      errorMessage = '내 즐겨찾기 목록을 불러오지 못했습니다.';
      // 네트워크 실패나 403은 로그아웃하지 않고 재시도만 안내. 만료·무효 토큰일 때만 현재 세션을 정리
      if (error is DioException && isSessionExpiredCode(apiErrorCode(error))) {
        await onSessionExpired?.call();
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
