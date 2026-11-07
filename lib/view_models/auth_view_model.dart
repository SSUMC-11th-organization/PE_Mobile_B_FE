import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
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
// 토큰·비밀번호는 필드로 보관하지 않고, print/log/화면 문구에도 쓰지 않음
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authService, this._memberApi, this._tokenStorage);

  // GET /v7/members/me 401 중 "저장된 토큰을 버려야 하는" 코드 (만료·위조·형식 오류 등)
  static const _invalidTokenCodes = {'AUTH401_2', 'AUTH401_3', 'AUTH401_4'};
  // POST /v7/auth/login 401 — 이메일/비밀번호 불일치. 로그인 폼 오류로만 처리
  static const _loginFailedCode = 'AUTH401_1';

  final AuthService _authService;
  final MemberApiService _memberApi;
  final TokenStorage _tokenStorage;

  AuthStatus _status = AuthStatus.initializing;
  // 세션이 바뀔 때(복원 시작, 로그인 시작, 로그아웃)마다 1씩 증가
  // 비동기 응답이 돌아왔을 때 자기 버전이 아니면 상태를 건드리지 않고 버림
  int _sessionVersion = 0;
  // restoreSession 성공 시 /v7/members/me 결과. 로그인 직후에는 null → loadMember()로 채움
  MemberInfo? _member;
  MemberLoadStatus _memberLoadStatus = MemberLoadStatus.idle;
  String? _memberErrorMessage; // 내 정보 조회 실패 (마이페이지에 표시)
  String? _loginErrorMessage; // 로그인 요청 실패 / 토큰 저장 실패 (로그인 화면 폼 아래 표시)
  String? _sessionErrorMessage; // 세션 확인 실패 (재시도 화면에 표시)
  String? _signedOutNotice; // 세션 만료 등으로 로그아웃된 이유 (로그인 화면 안내)
  bool _disposed = false;

  AuthStatus get status => _status;
  int get sessionVersion => _sessionVersion;
  MemberInfo? get member => _member;
  MemberLoadStatus get memberLoadStatus => _memberLoadStatus;
  String? get memberErrorMessage => _memberErrorMessage;
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

    // 로그인 직후에는 /v7/members/me를 호출하지 않음 — MainScreen이 loadMember()로 채움
    _clearMember();
    _status = AuthStatus.signedIn;
    _notify();
  }

  // signedIn인데 member가 없을 때(로그인 직후 등) 한 번 조회 — MainScreen이 처음 열릴 때 호출
  // restoreSession이 이미 채웠거나 조회 중이면 다시 부르지 않음
  // 401도 지금은 일반 오류로만 표시 (토큰 삭제·로그아웃 없음)
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
      if (!_isCurrent(version)) return;
      _memberLoadStatus = MemberLoadStatus.error;
      _memberErrorMessage = isNetworkError(e)
          ? '네트워크 연결을 확인한 뒤 다시 시도해 주세요.'
          : apiErrorMessage(e) ?? '내 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
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

  // 입력이 바뀌면 이전 로그인 실패 문구를 지움
  void clearLoginError() {
    if (_loginErrorMessage == null && _signedOutNotice == null) return;
    _loginErrorMessage = null;
    _signedOutNotice = null;
    _notify();
  }

  String _loginErrorFor(DioException e) {
    if (isNetworkError(e)) return '네트워크 연결을 확인해 주세요.';
    final status = e.response?.statusCode;
    final serverMessage = apiErrorMessage(e);
    if (status == 401 && apiErrorCode(e) == _loginFailedCode) {
      return serverMessage ?? '이메일 또는 비밀번호가 올바르지 않습니다.';
    }
    if (status == 400) return serverMessage ?? '입력한 내용을 다시 확인해 주세요.';
    return serverMessage ?? '로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.';
  }

  String _sessionCheckMessage(DioException e) {
    if (isNetworkError(e)) {
      return '서버에 연결하지 못해 로그인 상태를 확인하지 못했습니다. 네트워크를 확인한 뒤 다시 시도해 주세요.';
    }
    final status = e.response?.statusCode;
    return '로그인 상태를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.'
        '${status == null ? '' : ' ($status)'}';
  }

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

  void _setSignedOut({String? notice}) {
    _clearMember();
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
