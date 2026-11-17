import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jay/core/network/api_error.dart';
import 'package:jay/data/models/login_models.dart';
import 'package:jay/data/models/member_info.dart';
import 'package:jay/data/services/auth_api_service.dart';
import 'package:jay/data/services/member_api_service.dart';
import 'package:jay/storage/install_flag.dart';
import 'package:jay/storage/token_storage.dart';

enum AuthStatus {
  initializing,
  signedOut,
  authenticating,
  signedIn,
  retryRequired,
}

enum MemberLoadStatus { idle, loading, success, error }

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(
    this._authApi,
    this._memberApi,
    this._storage, {
    InstallFlag? installFlag,
  }) : _installFlag = installFlag;

  final AuthApiService _authApi;
  final MemberApiService _memberApi;
  final TokenStorage _storage;
  final InstallFlag? _installFlag;

  AuthStatus status = AuthStatus.initializing;
  MemberInfo? member;
  String? message;
  int _sessionVersion = 0;
  int get sessionVersion => _sessionVersion;
  bool sessionExpired = false;
  bool storageCleanUpInProgress = false;
  bool _disposed = false;
  Future<void>? _tokenWrite;
  MemberLoadStatus memberStatus = MemberLoadStatus.idle;

  Future<void> loadMember({bool force = false}) async {
    if (status != AuthStatus.signedIn) return;
    if (memberStatus == MemberLoadStatus.loading) return;
    if (member != null && !force) return;

    final version = _sessionVersion;
    memberStatus = MemberLoadStatus.loading;
    notifyListeners();

    try {
      final me = await _memberApi.fetchMe();
      if (version != _sessionVersion) return;
      member = me;
      memberStatus = MemberLoadStatus.success;
    } on DioException catch (error) {
      if (version != _sessionVersion) return;
      if (isSessionExpiredCode(apiErrorCode(error))) {
        await _clearCurrentSession();
        return;
      }
      memberStatus = MemberLoadStatus.error;
    } catch (_) {
      // 응답 형식 오류 등도 로그아웃하지 않고 재시도할 수 있게 둡니다.
      if (version != _sessionVersion) return;
      memberStatus = MemberLoadStatus.error;
    }
    _notify();
  }

  void updateMember(MemberInfo updated) {
    if (_disposed || status != AuthStatus.signedIn) return;
    member = updated;
    notifyListeners();
  }

  /// 다른 ViewModel이 보호 요청에서 AUTH401_2/3/4를 받았을 때 호출하는 공개 진입점입니다.
  /// [version]은 요청을 보내기 전에 읽어 둔 sessionVersion입니다.
  /// 이전 세션에서 늦게 도착한 401이 새로 로그인한 세션을 지우지 않도록 비교합니다.
  /// 동시에 여러 401이 와도 첫 호출 이후에는 signedOut이므로 정리·안내는 한 번만 실행됩니다.
  Future<void> expireSession({int? version}) async {
    if (version != null && version != _sessionVersion) return;
    if (status != AuthStatus.signedIn) return;
    await _clearCurrentSession(expired: true);
  }

  /// 10. 직접 로그아웃: 저장소·메모리 세션을 비우지만 만료 Snackbar는 켜지 않습니다.
  /// 서버에서 토큰이 즉시 폐기된다고 보장하지는 않습니다.
  Future<void> logout() => _clearCurrentSession(expired: false);

  void consumeSessionExpired() {
    sessionExpired = false;
  }

  bool _isCurrent(int version) => !_disposed && version == _sessionVersion;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> login(String email, String password) async {
    if (_disposed ||
        storageCleanUpInProgress ||
        status == AuthStatus.authenticating)
      return;
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
      status = AuthStatus.signedIn;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
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

  Future<void> _clearCurrentSession({bool expired = true}) async {
    if (_disposed || storageCleanUpInProgress) return;
    final version = ++_sessionVersion;
    storageCleanUpInProgress = true;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = expired;
    status = AuthStatus.signedOut;
    message = null;
    _notify();
    try {
      try {
        await _tokenWrite;
      } catch (_) {}
      await _storage.deleteAccessToken();
    } catch (_) {
      if (_isCurrent(version))
        message = '저장된 인증 정보를 지우지 못했어요. 앱 재실행 전에 저장소 상태를 확인해 주세요.';
    } finally {
      storageCleanUpInProgress = false;
      if (_isCurrent(version)) _notify();
    }
  }

  Future<void> restoreSession() async {
    if (storageCleanUpInProgress || _disposed) return;
    final version = ++_sessionVersion;
    status = AuthStatus.initializing;
    message = null;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    _notify();
    try {
      // (심화) 최초 설치라면 이전 설치에서 남은 토큰을 먼저 정리합니다.
      await _installFlag?.ensureInitialized();
      if (!_isCurrent(version)) return;
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
      status = AuthStatus.retryRequired;
      message = '로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.';
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.retryRequired;
      message = '인증 저장소를 읽지 못했어요. 다시 시도해 주세요.';
    }
    if (_isCurrent(version)) _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionVersion++;
    super.dispose();
  }
}
