import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// apiErrorCode는 8주차에서 이미 사용한 오류 code 추출 함수를 import합니다.
import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/safe_notify.dart';
import '../data/services/favorite_api_service.dart';

class FavoriteDetailViewModel extends ChangeNotifier with SafeNotify {
  FavoriteDetailViewModel({
    required this.movieId,
    required this.favoriteApi,
    required this.sessionGuard,
    required this.accountId,
    this.onSessionExpired,
  });

  // 상세 화면의 TMDB 영화 ID입니다. 즐겨찾기 경로에는 favoriteId가 아니라 이 값을 씁니다.
  final int movieId;
  final FavoriteApiService favoriteApi;
  final SessionGuard sessionGuard;
  final String accountId;
  // 만료·무효 토큰(AUTH401_2/3/4)이면 8주차처럼 AuthViewModel.expireSession으로 세션을 정리합니다.
  // Route에서 이 ViewModel을 만든 세션의 sessionVersion을 담아 전달합니다.
  final Future<void> Function()? onSessionExpired;

  // 401이면 세션을 정리하고 true를 반환합니다. 네트워크 실패·403은 로그아웃하지 않습니다.
  Future<bool> _expireIfUnauthorized(Object error) async {
    if (error is! DioException || !isSessionExpiredCode(apiErrorCode(error))) {
      return false;
    }
    await onSessionExpired?.call();
    return true;
  }

  bool isFavorite = false;
  bool hasLoadedStatus = false;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  ({int generation, bool ok}) _snapshot() {
    final generation = sessionGuard.generation;
    return (
      generation: generation,
      ok: sessionGuard.isCurrent(generation, accountId) && !isDisposed,
    );
  }

  Future<void> load() async {
    if (isLoading || isSaving) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    isLoading = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      final result = await favoriteApi.checkFavorite(movieId: movieId);
      if (!sessionGuard.isCurrent(snap.generation, accountId) || isDisposed) {
        return;
      }
      isFavorite = result.isFavorite;
      hasLoadedStatus = true;
    } catch (error) {
      if (!sessionGuard.isCurrent(snap.generation, accountId) || isDisposed) {
        return;
      }
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
      if (await _expireIfUnauthorized(error)) return;
    } finally {
      if (sessionGuard.isCurrent(snap.generation, accountId) && !isDisposed) {
        isLoading = false;
        notifyIfAlive();
      }
    }
  }

  // 서버 성공을 확인한 뒤에 북마크 상태를 바꿉니다. 요청 중에는 중복 탭을 막습니다.
  Future<void> toggle() async {
    if (isSaving || isLoading || !hasLoadedStatus) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    final before = isFavorite;
    isSaving = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      if (before) {
        await favoriteApi.deleteFavorite(movieId: movieId);
        if (!sessionGuard.isCurrent(snap.generation, accountId) || isDisposed) {
          return;
        }
        isFavorite = false;
      } else {
        await favoriteApi.addFavorite(movieId: movieId);
        if (!sessionGuard.isCurrent(snap.generation, accountId) || isDisposed) {
          return;
        }
        isFavorite = true;
      }
    } on DioException catch (error) {
      if (!sessionGuard.isCurrent(snap.generation, accountId) || isDisposed) {
        return;
      }
      isFavorite = before;
      if (await _expireIfUnauthorized(error)) {
        errorMessage = '로그인이 만료되었습니다. 다시 로그인해 주세요.';
        return;
      }
      // 이미 등록(409)이거나 이미 해제(404)이면 서버의 현재 여부로 화면을 맞춥니다.
      final code = apiErrorCode(error);
      if (code == 'FAVORITE409_1' || code == 'FAVORITE404_1') {
        try {
          final synced = await favoriteApi.checkFavorite(movieId: movieId);
          if (!sessionGuard.isCurrent(snap.generation, accountId) ||
              isDisposed) {
            return;
          }
          isFavorite = synced.isFavorite;
          errorMessage = null;
        } catch (_) {
          if (!sessionGuard.isCurrent(snap.generation, accountId) ||
              isDisposed) {
            return;
          }
          isFavorite = before;
          errorMessage = '서버 상태를 다시 확인하지 못했습니다.';
        }
      } else {
        isFavorite = before;
        errorMessage = before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.';
      }
    } catch (_) {
      if (!sessionGuard.isCurrent(snap.generation, accountId) || isDisposed) {
        return;
      }
      isFavorite = before;
      errorMessage = before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.';
    } finally {
      if (sessionGuard.isCurrent(snap.generation, accountId) && !isDisposed) {
        isSaving = false;
        notifyIfAlive();
      }
    }
  }
}
