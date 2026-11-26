import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/safe_notify.dart';
import '../data/services/favorite_api_service.dart';

/// 영화 상세의 즐겨찾기 버튼 상태.
/// isLoading(첫 여부 조회) / isSaving(등록·해제 중) / isFavorite(서버에서 확인한 값) / errorMessage.
/// 서버 성공을 확인한 뒤에만 북마크를 바꿈 (결과를 기다리지 않고 먼저 바꾸는 optimistic update는 쓰지 않음)
class FavoriteDetailViewModel extends ChangeNotifier with SafeNotify {
  FavoriteDetailViewModel({
    required this.movieId,
    required this.favoriteApi,
    required this.sessionGuard,
    required this.accountId,
    this.onSessionExpired,
  });

  // 상세 화면의 TMDB 영화 ID. 즐겨찾기 경로에는 favoriteId가 아니라 이 값을 씀
  final int movieId;
  final FavoriteApiService favoriteApi;
  final SessionGuard sessionGuard;
  final String accountId;
  // 보호 요청에서 만료·무효 토큰(AUTH401_2/3/4)을 받았을 때 호출. Route에서 AuthViewModel.expireSession을 연결
  final Future<void> Function()? onSessionExpired;

  bool isFavorite = false;
  bool hasLoadedStatus = false;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  bool sessionExpired =
      false; // 만료 안내는 로그인 화면이 한 번만 띄우므로 버튼 쪽 Snackbar를 생략하는 데 사용

  // 요청을 보내는 시점의 세션 번호와, 지금 요청을 보내도 되는지를 record로 한 번에 반환
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
      // 로그아웃·계정 전환·화면 이탈 뒤 늦게 도착한 응답은 반영하지 않음
      if (!sessionGuard.isCurrent(snap.generation, accountId) || isDisposed) {
        return;
      }
      isFavorite = result.isFavorite;
      hasLoadedStatus = true;
    } catch (error) {
      // 이전 계정에서 늦게 도착한 401이 현재 계정을 로그아웃시키지 않도록 세션부터 확인
      if (!sessionGuard.isCurrent(snap.generation, accountId) || isDisposed) {
        return;
      }
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
      // 네트워크 실패나 403은 안내만 하고, 만료·무효 토큰일 때만 현재 세션을 정리
      if (error is DioException && isSessionExpiredCode(apiErrorCode(error))) {
        await onSessionExpired?.call();
      }
    } finally {
      if (sessionGuard.isCurrent(snap.generation, accountId) && !isDisposed) {
        isLoading = false;
        notifyIfAlive();
      }
    }
  }

  // 요청 중에는 중복 탭을 막고, 실패하면 이전 아이콘 상태를 유지
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
      // 이미 등록(409)이거나 이미 해제(404)이면 같은 요청을 반복하지 않고 서버의 현재 여부로 화면을 맞춤
      final code = apiErrorCode(error);
      if (isSessionExpiredCode(code)) {
        // 세션을 정리하면 Router가 /login으로 보내고, 로그인 화면이 만료 안내를 띄움
        isFavorite = before;
        errorMessage = '로그인이 만료됐어요. 다시 로그인해 주세요.';
        sessionExpired = true;
        await onSessionExpired?.call();
      } else if (code == 'FAVORITE409_1' || code == 'FAVORITE404_1') {
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
