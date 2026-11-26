import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/network/auth_interceptor.dart';
import '../core/storage/token_storage.dart';
import '../data/models/auth_models.dart';
import '../data/models/member_info.dart';
import '../data/services/api_response.dart';
import '../data/services/auth_service.dart';
import '../data/services/member_api_service.dart';

enum AuthStatus { initializing, signedOut, authenticating, signedIn, retryRequired }

// 내 정보(member) 조회 상태 — signedIn 이후 loadMember()에서 사용
enum MemberLoadStatus { idle, loading, success, error }

// 앱 전체 인증 상태 — GoRouter refreshListenable로 연결되어 상태가 바뀌면 redirect가 다시 계산됨
// 보호용 Dio의 AuthInterceptor가 401(AUTH401_2/3/4)을 받으면 expireSession()을 호출 (SessionExpiryHandler)
// 토큰·비밀번호는 필드로 보관하지 않고, print/log/화면 문구에도 쓰지 않음
class AuthViewModel extends ChangeNotifier implements SessionExpiryHandler {
  AuthViewModel(
    this._authService,
    this._memberApi,
    this._tokenStorage, {
    this._onSessionEnded, // 호출하는 쪽에서는 onSessionEnded:로 전달
    this._onSignedIn, // 호출하는 쪽에서는 onSignedIn:으로 전달
  });

  // 사용자 세션 데이터(이번 세션 평점, 학습용 memberId) 정리 — main.dart에서 연결
  // logout / expireSession 때 호출. TMDB 설정·공개 영화 목록은 대상이 아님
  final VoidCallback? _onSessionEnded;
  // 로그인 성공 시 호출 — 다른 사용자로 전환된 경우의 정리 (로그인 이메일 전달, 비밀번호는 전달하지 않음)
  final void Function(String email)? _onSignedIn;

  static const _sessionExpiredMessage = '로그인이 만료되었습니다. 다시 로그인해 주세요.';

  final AuthService _authService;
  final MemberApiService _memberApi;
  final TokenStorage _tokenStorage;

  AuthStatus _status = AuthStatus.initializing;
  // 세션이 바뀔 때(복원 시작, 로그인 시작, 로그아웃, 세션 만료)마다 1씩 증가
  // 비동기 응답이 돌아왔을 때 자기 버전이 아니면 상태를 건드리지 않고 버림
  int _sessionVersion = 0;
  // restoreSession 성공 시 /v8/members/me 결과. 로그인 직후에는 null → loadMember()로 채움
  MemberInfo? _member;
  MemberLoadStatus _memberLoadStatus = MemberLoadStatus.idle;
  String? _memberErrorMessage; // 내 정보 조회 실패 (마이페이지에 표시)
  String? _loginErrorMessage; // 로그인 요청 실패 / 토큰 저장 실패 (로그인 화면 폼 아래 표시)
  String? _sessionErrorMessage; // 세션 확인 실패 (재시도 화면에 표시)
  String? _signedOutNotice; // 로그아웃 중 토큰 삭제 실패 안내 (로그인 화면 폼 위 문구)
  // 세션 만료 안내 — expireSession()에서만 설정, 로그인 화면이 Snackbar로 한 번 보여주고 비움
  // 정상 로그아웃·앱 시작 시 토큰 없음에서는 설정되지 않음
  String? _sessionExpiredNotice;
  bool _disposed = false;

  AuthStatus get status => _status;
  @override
  int get sessionVersion => _sessionVersion;
  MemberInfo? get member => _member;
  MemberLoadStatus get memberLoadStatus => _memberLoadStatus;
  String? get memberErrorMessage => _memberErrorMessage;
  String? get loginErrorMessage => _loginErrorMessage;
  String? get sessionErrorMessage => _sessionErrorMessage;
  String? get signedOutNotice => _signedOutNotice;
  String? get sessionExpiredNotice => _sessionExpiredNotice;
  bool get isAuthenticating => _status == AuthStatus.authenticating;

  // 앱 시작(및 재시도 화면의 재시도) — 토큰이 있고 /v8/members/me가
  // 2xx + isSuccess true + result가 MemberInfo로 파싱돼야만 signedIn (파싱 결과는 member로 보관)
  Future<void> restoreSession() async {
    if (_status == AuthStatus.authenticating) return;
    final version = ++_sessionVersion;
    _status = AuthStatus.initializing;
    _clearMember();
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
      final me = await _memberApi.fetchMe();
      if (!_isCurrent(version)) return;
      _member = me;
      _memberLoadStatus = MemberLoadStatus.success; // loadMember()가 다시 부르지 않도록
      _status = AuthStatus.signedIn;
      _notify();
    } on DioException catch (e) {
      // 401(AUTH401_2/3/4)은 인터셉터가 이미 expireSession을 호출해 버전이 바뀌었으므로 여기서 끝남
      if (!_isCurrent(version)) return;
      final kind = classifyApiError(e);
      if (kind == ApiErrorKind.sessionExpired) {
        // 인터셉터가 연결되지 않은 경우를 위한 같은 경로 (버전 확인으로 중복 실행 없음)
        await expireSession(sessionVersion: version);
        return;
      }
      // 네트워크 실패·서버 오류·그 외 401 등 → 토큰은 지우지 않고 재시도 대기
      _setRetryRequired(_sessionCheckMessage(kind));
    } on InvalidApiResponseException {
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
    _sessionExpiredNotice = null;
    _notify();

    final LoginResult result;
    try {
      result = await _authService.login(
        LoginRequest(email: email, password: password),
      );
    } on DioException catch (e) {
      if (!_isCurrent(version)) return;
      _failLogin(_loginErrorFor(e)); // 공개용 Dio — 401(AUTH401_1)은 세션 만료로 가지 않음
      return;
    } on InvalidApiResponseException {
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

    // 로그인 직후에는 /v8/members/me를 호출하지 않음 — MainScreen이 loadMember()로 채움
    _clearMember();
    _onSignedIn?.call(email);
    _status = AuthStatus.signedIn;
    _notify();
  }

  // signedIn인데 member가 없을 때(로그인 직후 등) 한 번 조회 — MainScreen이 처음 열릴 때 호출
  // restoreSession이 이미 채웠거나 조회 중이면 다시 부르지 않음
  // 401(AUTH401_2/3/4)은 expireSession 경로로만 처리하고 오류 문구는 남기지 않음
  Future<void> loadMember() async {
    if (_status != AuthStatus.signedIn) return;
    if (_member != null || _memberLoadStatus == MemberLoadStatus.loading) return;
    final version = _sessionVersion;
    _memberLoadStatus = MemberLoadStatus.loading;
    _memberErrorMessage = null;
    _notify();

    try {
      final me = await _memberApi.fetchMe();
      if (!_isCurrent(version)) return; // 로그아웃/회원 전환 뒤 늦게 온 응답은 버림
      _member = me;
      _memberLoadStatus = MemberLoadStatus.success;
    } on DioException catch (e) {
      if (!_isCurrent(version)) return; // 인터셉터가 만료 처리했으면 여기서 끝남
      final kind = classifyApiError(e);
      if (kind == ApiErrorKind.sessionExpired) {
        await expireSession(sessionVersion: version);
        return;
      }
      _memberLoadStatus = MemberLoadStatus.error;
      _memberErrorMessage = _memberLoadMessage(kind, apiErrorMessage(e));
    } on InvalidApiResponseException {
      if (!_isCurrent(version)) return;
      _memberLoadStatus = MemberLoadStatus.error;
      _memberErrorMessage = '내 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
    _notify();
  }

  // 프로필 수정 성공 시 응답 MemberInfo로 교체
  // 요청을 시작한 세션(version)이 아직 유효하고 signedIn일 때만 반영 — 반영했으면 true
  bool replaceMember(MemberInfo member, {required int sessionVersion}) {
    if (!_isCurrent(sessionVersion) || _status != AuthStatus.signedIn) {
      return false;
    }
    _member = member;
    _memberLoadStatus = MemberLoadStatus.success;
    _memberErrorMessage = null;
    _notify();
    return true;
  }

  // 로그아웃 — 버전을 올려 진행 중인 이전 응답을 무효화 → 토큰 삭제 → member 비우기 → signedOut
  // signedOut이 되면 GoRouter redirect가 /login으로 이동
  // 세션 만료 안내는 띄우지 않음. TMDB 설정·공개 영화 데이터는 건드리지 않음
  Future<void> logout() async {
    final version = ++_sessionVersion;
    _clearMember();
    _onSessionEnded?.call();
    _loginErrorMessage = null;
    _sessionErrorMessage = null;

    String? notice;
    try {
      await _tokenStorage.deleteAccessToken();
    } catch (_) {
      notice = '기기에 저장된 로그인 정보를 지우지 못했습니다.';
    }
    if (!_isCurrent(version)) return;
    _signedOutNotice = notice; // 정상 로그아웃이면 null → 로그인 화면에 안내 없음
    _status = AuthStatus.signedOut;
    _notify();
  }

  // 세션 만료 — 보호 요청이 401(AUTH401_2/3/4)을 받았을 때 (인터셉터·restoreSession·loadMember 공통 경로)
  // 요청 시점 버전이 현재와 다르면(로그아웃·재로그인·이미 만료 처리) 조용히 버림
  // → 동시에 여러 401이 와도 첫 번째만 반영 (버전을 await 전에 올리므로 후속 응답은 모두 stale)
  // 네트워크·5xx·403·409·400은 여기로 오지 않음 → 토큰 유지
  @override
  Future<void> expireSession({required int sessionVersion}) async {
    if (!_isCurrent(sessionVersion)) return;
    if (_status != AuthStatus.signedIn && _status != AuthStatus.initializing) {
      return;
    }
    final version = ++_sessionVersion;
    _clearMember();
    _onSessionEnded?.call();
    _loginErrorMessage = null;
    _sessionErrorMessage = null;
    // signedOut 전에 삭제를 끝냄 — 바로 재로그인해 저장한 새 토큰을 늦은 삭제가 지우지 않도록
    await _deleteTokenQuietly();
    if (!_isCurrent(version)) return;
    _signedOutNotice = null;
    _sessionExpiredNotice = _sessionExpiredMessage;
    _status = AuthStatus.signedOut; // redirect → /login
    _notify();
  }

  // 로그인 화면이 Snackbar로 한 번 보여줄 만료 안내를 꺼내고 비움 (두 번째 호출부터 null)
  // 화면 표시용으로만 비우므로 notifyListeners 하지 않음
  String? takeSessionExpiredNotice() {
    final notice = _sessionExpiredNotice;
    _sessionExpiredNotice = null;
    return notice;
  }

  // 입력이 바뀌면 이전 로그인 실패 문구를 지움
  void clearLoginError() {
    if (_loginErrorMessage == null && _signedOutNotice == null) return;
    _loginErrorMessage = null;
    _signedOutNotice = null;
    _notify();
  }

  String _loginErrorFor(DioException e) {
    final serverMessage = apiErrorMessage(e);
    return switch (classifyApiError(e)) {
      ApiErrorKind.network => '네트워크 연결을 확인해 주세요.',
      ApiErrorKind.loginFailed =>
        serverMessage ?? '이메일 또는 비밀번호가 올바르지 않습니다.',
      ApiErrorKind.validation => serverMessage ?? '입력한 내용을 다시 확인해 주세요.',
      ApiErrorKind.server => '서버에 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.',
      _ => serverMessage ?? '로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.',
    };
  }

  String _sessionCheckMessage(ApiErrorKind kind) => switch (kind) {
        ApiErrorKind.network =>
          '서버에 연결하지 못해 로그인 상태를 확인하지 못했습니다. 네트워크를 확인한 뒤 다시 시도해 주세요.',
        ApiErrorKind.server =>
          '서버에 문제가 있어 로그인 상태를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.',
        _ => '로그인 상태를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      };

  String _memberLoadMessage(ApiErrorKind kind, String? serverMessage) =>
      switch (kind) {
        ApiErrorKind.network => '네트워크 연결을 확인한 뒤 다시 시도해 주세요.',
        ApiErrorKind.server => '서버에 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.',
        ApiErrorKind.forbidden => serverMessage ?? '내 정보를 볼 권한이 없습니다.',
        _ => serverMessage ?? '내 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
      };

  void _failLogin(String message) {
    _loginErrorMessage = message;
    _status = AuthStatus.signedOut;
    _notify();
  }

  void _clearMember() {
    _member = null;
    _memberLoadStatus = MemberLoadStatus.idle;
    _memberErrorMessage = null;
  }

  // 앱 시작 시 토큰 없음 — 만료 안내 없이 signedOut
  void _setSignedOut() {
    _clearMember();
    _signedOutNotice = null;
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
      // 삭제 실패해도 다음 세션 확인에서 다시 401 → 만료 처리에서 삭제를 다시 시도함
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
