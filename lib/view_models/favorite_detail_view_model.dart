import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
    required this.onSessionExpired,
  });

  final int movieId;
  final FavoriteApiService favoriteApi;
  final SessionGuard sessionGuard;
  final String accountId;
  final Future<void> Function() onSessionExpired;

  bool isFavorite = false;
  bool hasLoadedStatus = false;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  /// 요청 시점의 세션이 지금도 유효하고 화면이 살아 있는지 확인합니다.
  bool _isAlive(int generation) =>
      !isDisposed && sessionGuard.isCurrent(generation, accountId);

  /// AUTH401_2/3/4면 세션을 정리하고 true를 돌려줍니다.
  Future<bool> _expiredBy(Object error) async {
    if (error is! DioException || !isSessionExpiredCode(apiErrorCode(error))) {
      return false;
    }
    await onSessionExpired();
    return true;
  }

  Future<void> load() async {
    final generation = sessionGuard.generation;
    if (isLoading || isSaving || !_isAlive(generation)) return;
    isLoading = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      final result = await favoriteApi.checkFavorite(movieId: movieId);
      if (!_isAlive(generation)) return;
      isFavorite = result.isFavorite;
      hasLoadedStatus = true;
    } catch (error) {
      if (!_isAlive(generation) || await _expiredBy(error)) return;
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
    } finally {
      if (_isAlive(generation)) {
        isLoading = false;
        notifyIfAlive();
      }
    }
  }

  /// 서버 성공을 확인한 뒤에 북마크를 바꿉니다.
  /// Snackbar에 보여 줄 문구를 돌려주며, null이면 아무것도 안내하지 않습니다.
  Future<String?> toggle() async {
    final generation = sessionGuard.generation;
    if (isSaving || isLoading || !hasLoadedStatus || !_isAlive(generation)) {
      return null;
    }
    final before = isFavorite;
    isSaving = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      if (before) {
        await favoriteApi.deleteFavorite(movieId: movieId);
      } else {
        await favoriteApi.addFavorite(movieId: movieId);
      }
      if (!_isAlive(generation)) return null;
      isFavorite = !before;
    } catch (error) {
      if (!_isAlive(generation) || await _expiredBy(error)) return null;
      final code = error is DioException ? apiErrorCode(error) : null;
      // 이미 등록(409)·이미 해제(404)면 POST를 반복하지 않고 서버 상태로 맞춥니다.
      if (code == 'FAVORITE409_1' || code == 'FAVORITE404_1') {
        try {
          final synced = await favoriteApi.checkFavorite(movieId: movieId);
          if (!_isAlive(generation)) return null;
          isFavorite = synced.isFavorite;
        } catch (syncError) {
          if (!_isAlive(generation) || await _expiredBy(syncError)) return null;
          errorMessage = '서버 상태를 다시 확인하지 못했습니다.';
        }
      } else if (code == 'MEMBER404_1') {
        errorMessage = '회원 정보를 찾을 수 없습니다.';
      } else {
        errorMessage = before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.';
      }
    } finally {
      if (_isAlive(generation)) {
        isSaving = false;
        notifyIfAlive();
      }
    }
    return errorMessage ?? (isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.');
  }
}
