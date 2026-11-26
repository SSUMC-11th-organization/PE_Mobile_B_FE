import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/safe_notify.dart';
import '../data/services/favorite_api_service.dart';

// 영화 상세의 즐겨찾기 상태 — 상세 Route에서 ValueKey(email:generation)와 함께 생성
// - 서버 성공을 확인한 뒤에만 북마크를 바꿈 (optimistic update 없음)
// - 응답이 도착했을 때 세션(SessionGuard)이 바뀌었거나 dispose됐으면 반영하지 않음
// - 세션 만료(AUTH401_2/3/4)는 AuthInterceptor → AuthViewModel.expireSession이 전역 처리
//   → 여기서는 문구 없이 정리만 함. 네트워크 실패·403 등은 로그아웃하지 않음
class FavoriteDetailViewModel extends ChangeNotifier with SafeNotify {
  FavoriteDetailViewModel({
    required this.movieId,
    required this.favoriteApi,
    required this.sessionGuard,
    required this.accountId,
  });

  // 상세 화면의 TMDB 영화 ID — 즐겨찾기 경로에는 favoriteId가 아니라 이 값을 씀
  final int movieId;
  final FavoriteApiService favoriteApi;
  final SessionGuard sessionGuard;
  final String accountId; // /v8/members/me로 확인한 email

  bool isFavorite = false; // 서버에서 확인한 값
  bool hasLoadedStatus = false; // 첫 여부 조회 성공 여부 (실패면 버튼 비활성 + 다시 확인)
  bool isLoading = false; // 첫 여부 조회 중
  bool isSaving = false; // 등록·해제 중
  String? errorMessage;

  ({int generation, bool ok}) _snapshot() {
    final generation = sessionGuard.generation;
    return (
      generation: generation,
      ok: sessionGuard.isCurrent(generation, accountId) && !isDisposed,
    );
  }

  bool _isStale(int generation) =>
      !sessionGuard.isCurrent(generation, accountId) || isDisposed;

  static bool _isSessionExpired(Object error) =>
      error is DioException &&
      classifyApiError(error) == ApiErrorKind.sessionExpired;

  // 진입 시 한 번 — 서버의 즐겨찾기 여부를 북마크에 반영 (build에서는 호출하지 않음)
  Future<void> load() async {
    if (isLoading || isSaving) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    isLoading = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      final result = await favoriteApi.checkFavorite(movieId: movieId);
      if (_isStale(snap.generation)) return;
      isFavorite = result.isFavorite;
      hasLoadedStatus = true;
    } catch (error) {
      if (_isStale(snap.generation)) return;
      // 세션 만료는 전역 처리 → 문구 없음
      if (!_isSessionExpired(error)) {
        errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
      }
    } finally {
      if (!_isStale(snap.generation)) {
        isLoading = false;
        notifyIfAlive();
      }
    }
  }

  // 등록·해제 — 요청 중에는 중복 탭을 막음
  // 반환값: Snackbar로 보여줄 문구. null이면 안내하지 않음(세션 변경·만료, 요청 안 함)
  Future<String?> toggle() async {
    if (isSaving || isLoading || !hasLoadedStatus) return null;
    final snap = _snapshot();
    if (!snap.ok) return null;
    final before = isFavorite;
    final failMessage = before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.';
    isSaving = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      if (before) {
        // 200 + result null — DioException이 없으면 성공
        await favoriteApi.deleteFavorite(movieId: movieId);
        if (_isStale(snap.generation)) return null;
        isFavorite = false;
        return '즐겨찾기에서 삭제했습니다.';
      } else {
        // 자동 재시도하지 않음
        await favoriteApi.addFavorite(movieId: movieId);
        if (_isStale(snap.generation)) return null;
        isFavorite = true;
        return '즐겨찾기에 추가했습니다.';
      }
    } on DioException catch (error) {
      if (_isStale(snap.generation)) return null;
      if (_isSessionExpired(error)) {
        isFavorite = before;
        return null; // AuthInterceptor가 세션을 정리 → 로그인 화면으로 이동
      }
      // 이미 등록(409)·이미 해제(404)면 POST/DELETE를 반복하지 않고 서버의 현재 여부로 맞춤
      final code = apiErrorCode(error);
      if (code == 'FAVORITE409_1' || code == 'FAVORITE404_1') {
        // 409 = 이미 등록 → 채워진 북마크, 404 = 이미 해제 → 빈 북마크 (GET 확인이 실패해도 이 값으로 맞춤)
        return _syncFromServer(
          snap.generation,
          before,
          expected: code == 'FAVORITE409_1',
        );
      }
      isFavorite = before; // 실패하면 이전 아이콘 유지
      errorMessage = failMessage;
      return errorMessage;
    } catch (_) {
      if (_isStale(snap.generation)) return null;
      isFavorite = before;
      errorMessage = failMessage;
      return errorMessage;
    } finally {
      if (!_isStale(snap.generation)) {
        isSaving = false;
        notifyIfAlive();
      }
    }
  }

  // 409/404 뒤 서버의 현재 여부로 맞춤 — GET이 실패하면 오류 code가 알려 준 상태(expected)로 맞춤
  Future<String?> _syncFromServer(
    int generation,
    bool before, {
    required bool expected,
  }) async {
    try {
      final synced = await favoriteApi.checkFavorite(movieId: movieId);
      if (_isStale(generation)) return null;
      isFavorite = synced.isFavorite;
    } catch (error) {
      if (_isStale(generation)) return null;
      if (_isSessionExpired(error)) {
        isFavorite = before;
        return null;
      }
      isFavorite = expected;
    }
    errorMessage = null;
    return isFavorite ? '이미 즐겨찾기에 있는 영화입니다.' : '이미 즐겨찾기에서 삭제된 영화입니다.';
  }
}
