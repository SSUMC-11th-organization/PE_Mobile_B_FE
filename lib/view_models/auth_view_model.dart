import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/storage/token_storage.dart';
import '../data/models/auth_models.dart';
import '../data/models/member_info.dart';
import '../data/services/auth_service.dart';

enum AuthStatus { initializing, signedOut, authenticating, signedIn, retryRequired }

// 앱 전체 인증 상태 — GoRouter refreshListenable로 연결되어 상태가 바뀌면 redirect가 다시 계산됨
// 토큰·비밀번호는 필드로 보관하지 않고, print/log/화면 문구에도 쓰지 않음
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authService, this._tokenStorage);

  // GET /v7/members/me 401 중 "저장된 토큰을 버려야 하는" 코드 (만료·위조·형식 오류 등)
  static const _invalidTokenCodes = {'AUTH401_2', 'AUTH401_3', 'AUTH401_4'};
  // POST /v7/auth/login 401 — 이메일/비밀번호 불일치. 로그인 폼 오류로만 처리
  static const _loginFailedCode = 'AUTH401_1';

  final AuthService _authService;
  final TokenStorage _tokenStorage;

  AuthStatus _status = AuthStatus.initializing;
  // 세션이 바뀔 때(복원 시작, 로그인 시작, 로그아웃)마다 1씩 증가
  // 비동기 응답이 돌아왔을 때 자기 버전이 아니면 상태를 건드리지 않고 버림
  int _sessionVersion = 0;
  MemberInfo? _member; // restoreSession 성공 시 /v7/members/me 결과. 로그인 직후에는 null
  String? _loginErrorMessage; // 로그인 요청 실패 / 토큰 저장 실패 (로그인 화면 폼 아래 표시)
  String? _sessionErrorMessage; // 세션 확인 실패 (재시도 화면에 표시)
  String? _signedOutNotice; // 세션 만료 등으로 로그아웃된 이유 (로그인 화면 안내)
  bool _disposed = false;

  AuthStatus get status => _status;
  int get sessionVersion => _sessionVersion;
  MemberInfo? get member => _member;
  String? get loginErrorMessage => _loginErrorMessage;
  String? get sessionErrorMessage => _sessionErrorMessage;
  String? get signedOutNotice => _signedOutNotice;
  bool get isAuthenticating => _status == AuthStatus.authenticating;

  // 앱 시작(및 재시도 화면의 재시도) — 토큰이 있고 /v7/members/me가
  // 2xx + isSuccess true + result가 MemberInfo로 파싱돼야만 signedIn (파싱 결과는 member로 보관)
  Future<void> restoreSession() async {
    if (_status == AuthStatus.authenticating) return;
    final version = ++_sessionVersion;
    _status = AuthStatus.initializing;
    _member = null;
    _sessionErrorMessage = null;
    _notify();

    final String? token;
    try {
      token = await _tokenStorage.readAccessToken();
    } catch (_) {
      if (!_isCurrent(version)) return;
      _setRetryRequired('기기에 저장된 로그인 정보를 읽지 못했습니다. 다시 시도해 주세요.');
      return;
    }
    if (!_isCurrent(version)) return;
    if (token == null) {
      _setSignedOut();
      return;
    }

    try {
      final me = await _authService.fetchMe();
      if (!_isCurrent(version)) return;
      _member = me;
      _status = AuthStatus.signedIn;
      _notify();
    } on DioException catch (e) {
      if (!_isCurrent(version)) return;
      if (e.response?.statusCode == 401 &&
          _invalidTokenCodes.contains(apiErrorCode(e))) {
        // 서버가 토큰이 유효하지 않다고 확정한 경우에만 삭제
        await _deleteTokenQuietly();
        if (!_isCurrent(version)) return;
        _setSignedOut(notice: '로그인이 만료되었습니다. 다시 로그인해 주세요.');
        return;
      }
      // 네트워크 실패·서버 오류·그 외 401 → 토큰은 지우지 않고 재시도 대기
      _setRetryRequired(_sessionCheckMessage(e));
    } on AuthResponseException {
      if (!_isCurrent(version)) return;
      _setRetryRequired('로그인 상태를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  // 로그인 — 성공 시 accessToken만 저장 (비밀번호는 저장·보관하지 않음)
  Future<void> login({required String email, required String password}) async {
    if (_status != AuthStatus.signedOut) return; // 통신 중 중복 호출 무시
    final version = ++_sessionVersion;
    _status = AuthStatus.authenticating;
    _loginErrorMessage = null;
    _signedOutNotice = null;
    _notify();

    final LoginResult result;
    try {
      result = await _authService.login(
        LoginRequest(email: email, password: password),
      );
    } on DioException catch (e) {
      if (!_isCurrent(version)) return;
      _failLogin(_loginErrorFor(e));
      return;
    } on AuthResponseException {
      if (!_isCurrent(version)) return;
      _failLogin('로그인 응답을 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      return;
    }
    if (!_isCurrent(version)) return;

    try {
      await _tokenStorage.writeAccessToken(result.accessToken);
    } catch (_) {
      if (!_isCurrent(version)) return;
      await _deleteTokenQuietly(); // 일부만 저장됐을 가능성 정리
      if (!_isCurrent(version)) return;
      _failLogin('로그인에는 성공했지만 로그인 정보를 기기에 저장하지 못했습니다. 다시 시도해 주세요.');
      return;
    }
    if (!_isCurrent(version)) {
      // 저장하는 사이 로그아웃됨 → 방금 저장한 토큰이 남지 않도록 정리
      if (_status == AuthStatus.signedOut) await _deleteTokenQuietly();
      return;
    }

    // 로그인 직후에는 /v7/members/me를 호출하지 않음 — member는 이후 단계에서 채움
    _member = null;
    _status = AuthStatus.signedIn;
    _notify();
  }

  // 로그아웃 — 버전을 올려 진행 중인 이전 응답을 무효화한 뒤 토큰 삭제
  Future<void> logout() async {
    ++_sessionVersion;
    _member = null;
    _loginErrorMessage = null;
    _sessionErrorMessage = null;
    _status = AuthStatus.signedOut;
    _notify();
    try {
      await _tokenStorage.deleteAccessToken();
    } catch (_) {
      _signedOutNotice = '기기에 저장된 로그인 정보를 지우지 못했습니다.';
      _notify();
    }
  }

  // 입력이 바뀌면 이전 로그인 실패 문구를 지움
  void clearLoginError() {
    if (_loginErrorMessage == null && _signedOutNotice == null) return;
    _loginErrorMessage = null;
    _signedOutNotice = null;
    _notify();
  }

  String _loginErrorFor(DioException e) {
    if (_isNetworkError(e)) return '네트워크 연결을 확인해 주세요.';
    final status = e.response?.statusCode;
    final serverMessage = apiErrorMessage(e);
    if (status == 401 && apiErrorCode(e) == _loginFailedCode) {
      return serverMessage ?? '이메일 또는 비밀번호가 올바르지 않습니다.';
    }
    if (status == 400) return serverMessage ?? '입력한 내용을 다시 확인해 주세요.';
    return serverMessage ?? '로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.';
  }

  String _sessionCheckMessage(DioException e) {
    if (_isNetworkError(e)) {
      return '서버에 연결하지 못해 로그인 상태를 확인하지 못했습니다. 네트워크를 확인한 뒤 다시 시도해 주세요.';
    }
    final status = e.response?.statusCode;
    return '로그인 상태를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.'
        '${status == null ? '' : ' ($status)'}';
  }

  bool _isNetworkError(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError =>
          true,
        _ => false,
      };

  void _failLogin(String message) {
    _loginErrorMessage = message;
    _status = AuthStatus.signedOut;
    _notify();
  }

  void _setSignedOut({String? notice}) {
    _member = null;
    _signedOutNotice = notice;
    _status = AuthStatus.signedOut;
    _notify();
  }

  void _setRetryRequired(String message) {
    _sessionErrorMessage = message;
    _status = AuthStatus.retryRequired;
    _notify();
  }

  Future<void> _deleteTokenQuietly() async {
    try {
      await _tokenStorage.deleteAccessToken();
    } catch (_) {
      // 삭제 실패해도 다음 세션 확인에서 다시 401 → 삭제를 시도함
    }
  }

  bool _isCurrent(int version) => !_disposed && version == _sessionVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionVersion++;
    super.dispose();
  }
}
