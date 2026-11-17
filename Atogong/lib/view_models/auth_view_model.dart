import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/storage/token_storage.dart';
import '../data/models/login_models.dart';
import '../data/models/member_info.dart';
import '../data/services/auth_api_service.dart';
import '../data/services/member_api_service.dart';

/// initializing: 앱 시작 직후 저장된 토큰 확인 중 / signedOut: 로그인 필요 / authenticating: 로그인 요청 중
/// signedIn: 로그인됨 / retryRequired: 세션 확인 실패(네트워크 등). 토큰은 지우지 않고 재시도
enum AuthStatus {
  initializing,
  signedOut,
  authenticating,
  signedIn,
  retryRequired,
}

enum MemberLoadStatus { idle, loading, success, error }

/// 앱 전체의 인증 상태. 화면 이동은 직접 하지 않고 status만 바꾸면 Router의 redirect가 처리
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authApi, this._memberApi, this._storage);
  final AuthApiService _authApi;
  final MemberApiService _memberApi;
  final TokenStorage _storage;

  AuthStatus status = AuthStatus.initializing;
  MemberInfo? member;
  MemberLoadStatus memberStatus = MemberLoadStatus.idle;
  String? message;
  // 로그인·복원·로그아웃마다 1씩 증가. 이전 세션에서 늦게 도착한 응답이 새 세션을 건드리지 못하게 비교
  int _sessionVersion = 0;
  int get sessionVersion => _sessionVersion;
  bool sessionExpired = false; // 만료로 정리됐을 때만 true (직접 로그아웃·로그인 실패와 구분)
  bool storageCleanupInProgress = false;
  bool _disposed = false;
  Future<void>? _tokenWrite;

  bool _isCurrent(int version) => !_disposed && version == _sessionVersion;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---------- 로그인 ----------
  Future<void> login(String email, String password) async {
    if (_disposed ||
        storageCleanupInProgress ||
        status == AuthStatus.authenticating) {
      return;
    }
    status = AuthStatus.authenticating;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = false;
    message = null;
    final version = ++_sessionVersion;
    _notify();
    try {
      final result = await _authApi.login(
        LoginRequest(email: email, password: password),
      );
      if (!_isCurrent(version)) return;
      final writing = _storage.saveAccessToken(result.accessToken);
      _tokenWrite = writing;
      try {
        await writing;
      } finally {
        if (identical(_tokenWrite, writing)) _tokenWrite = null;
      }
      if (!_isCurrent(version)) return;
      // 신규 로그인: 토큰 저장 → signedIn → MainScreen.loadMember().
      // 앱 재시작은 restoreSession()의 GET me 검증 후에만 signedIn
      status = AuthStatus.signedIn;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      // AUTH401_1은 세션 만료가 아니라 입력 오류라 Form에 문구만 표시
      message = apiErrorCode(error) == 'AUTH401_1'
          ? '이메일 또는 비밀번호를 확인해 주세요.'
          : '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.';
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      message = '로그인 정보를 안전하게 저장하지 못했어요.';
    }
    _notify();
  }

  // ---------- 앱 시작 시 세션 복원 ----------
  /// 토큰 문자열이 있다는 것만으로 signedIn을 확정하지 않고, GET me로 서버 검증까지 거침
  Future<void> restoreSession() async {
    if (storageCleanupInProgress || _disposed) return;
    final version = ++_sessionVersion;
    status = AuthStatus.initializing;
    message = null;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    _notify();
    try {
      final token = await _storage.readAccessToken();
      if (!_isCurrent(version)) return;
      if (token == null || token.isEmpty) {
        status = AuthStatus.signedOut;
      } else {
        final verifiedMember = await _memberApi.fetchMe();
        if (!_isCurrent(version)) return;
        member = verifiedMember;
        memberStatus = MemberLoadStatus.success;
        status = AuthStatus.signedIn;
      }
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpiredCode(apiErrorCode(error))) {
        await _clearCurrentSession(expired: true);
        return;
      }
      // 네트워크가 잠시 끊겼다고 유효한 토큰을 지우지 않음 → 재시도 화면
      status = AuthStatus.retryRequired;
      message = '로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.';
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.retryRequired;
      message = '인증 저장소를 읽지 못했어요. 다시 시도해 주세요.';
    }
    if (_isCurrent(version)) _notify();
  }

  // ---------- 내 정보 ----------
  /// 로그인 직후 MainScreen이 한 번 호출. 재시작 때는 restoreSession()이 이미 member를 채워 다시 호출하지 않음
  Future<void> loadMember({bool force = false}) async {
    if (status != AuthStatus.signedIn) return;
    if (memberStatus == MemberLoadStatus.loading) return;
    if (member != null && !force) return;

    final version = _sessionVersion;
    memberStatus = MemberLoadStatus.loading;
    _notify();

    try {
      final me = await _memberApi.fetchMe();
      if (!_isCurrent(version)) return; // 로그아웃·계정 전환 뒤 늦게 온 응답 무시
      member = me;
      memberStatus = MemberLoadStatus.success;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpiredCode(apiErrorCode(error))) {
        await _clearCurrentSession(); // signedOut이 되어 Router가 /login으로 이동
        return;
      }
      memberStatus = MemberLoadStatus.error; // 네트워크 실패: 로그아웃하지 않고 재시도 가능
      message = '내 정보를 불러오지 못했어요.';
    } catch (_) {
      if (!_isCurrent(version)) return;
      memberStatus = MemberLoadStatus.error;
      message = '내 정보를 불러오지 못했어요.';
    }
    _notify();
  }

  /// 프로필 수정 성공 응답으로 메모리의 내 정보를 교체. GET me를 다시 호출하지 않음
  void updateMember(MemberInfo updated) {
    if (_disposed || status != AuthStatus.signedIn) return;
    member = updated;
    notifyListeners();
  }

  // ---------- 세션 정리 ----------
  /// 다른 ViewModel이 보호 요청에서 401(AUTH401_2/3/4)을 받았을 때 호출하는 공개 진입점
  Future<void> expireSession() => _clearCurrentSession(expired: true);

  /// 직접 로그아웃. 토큰과 메모리를 함께 비우지만 만료 Snackbar는 켜지 않음.
  /// 클라이언트 쪽 세션만 비우는 것이고, 서버에서 토큰이 즉시 폐기된다는 뜻은 아님
  Future<void> logout() => _clearCurrentSession(expired: false);

  /// 로그인 화면이 만료 안내 Snackbar를 한 번 띄운 뒤 호출해 반복 표시를 막음
  void consumeSessionExpired() {
    sessionExpired = false;
  }

  Future<void> _clearCurrentSession({bool expired = true}) async {
    if (_disposed || storageCleanupInProgress) return;
    final version = ++_sessionVersion;
    storageCleanupInProgress = true;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = expired;
    status = AuthStatus.signedOut;
    message = null;
    _notify();
    try {
      // 진행 중이던 토큰 저장을 기다린 뒤 삭제. 정리 중 새 로그인은 막음
      try {
        await _tokenWrite;
      } catch (_) {
        /* 저장 실패여도 삭제는 시도 */
      }
      await _storage.deleteAccessToken();
    } catch (_) {
      if (_isCurrent(version)) {
        message = '저장된 인증 정보를 지우지 못했어요. 앱 재실행 전에 저장소 상태를 확인해 주세요.';
      }
    } finally {
      storageCleanupInProgress = false;
      if (_isCurrent(version)) _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionVersion++;
    super.dispose();
  }
}
