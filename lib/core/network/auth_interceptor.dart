import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_error.dart';

// 인터셉터가 세션 버전을 읽고 만료를 알릴 대상 (AuthViewModel이 구현)
// Dio → AuthViewModel 직접 의존(순환)을 피하려고 인터페이스로 분리
abstract interface class SessionExpiryHandler {
  int get sessionVersion;

  // requestSessionVersion이 현재 세션과 다르면(로그아웃·재로그인·이미 만료 처리) 아무것도 하지 않아야 함
  Future<void> expireSession({required int sessionVersion});
}

// MovieLog 보호용 Dio에만 붙이는 인터셉터
// - onRequest: 저장소에서 MovieLog JWT를 읽어 Bearer로 첨부 + 요청 시점의 sessionVersion 기록
// - onError: 401(AUTH401_2/3/4)이면 기록해 둔 버전으로 세션 만료 처리 요청
// - TMDB Dio, MovieLog 공개용 Dio(로그인 포함)에는 붙이지 않음 → 그 요청들의 401은 여기로 오지 않음
// - 토큰 값은 로그로 남기지 않음
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage, {required this.allowedHost});

  final TokenStorage _tokenStorage;

  // JWT를 보내고 만료를 처리하는 유일한 호스트 (MovieLog 서버) — 다른 호스트 요청은 건드리지 않음
  final String allowedHost;

  // 앱 시작 시 main.dart에서 연결 (연결 전에는 만료 처리를 하지 않음)
  SessionExpiryHandler? sessionHandler;

  static const _header = 'Authorization';
  static const _sessionVersionKey = 'movielog.sessionVersion';

  // 보호 요청(JWT를 붙일 요청)인지 판단 — 호스트와 경로(/v8)·메서드를 함께 확인
  bool _isProtected(RequestOptions options) {
    // MovieLog 서버가 아닌 곳(TMDB 등)에는 JWT를 붙이지 않음
    if (options.uri.host != allowedHost) return false;
    final path = options.uri.path;
    final method = options.method.toUpperCase();

    // 8주차 보호 경로(/v8로 전환). 로그인·회원가입·중복 확인은 보호 요청이 아님
    final w8Protected = path == '/v8/members/me' ||
        path == '/v8/ratings' ||
        path.startsWith('/v8/ratings/');

    // 즐겨찾기: 등록(POST)·목록(GET) / 여부 조회(GET)·해제(DELETE)
    final favorites = (path == '/v8/favorites' &&
            (method == 'GET' || method == 'POST')) ||
        (RegExp(r'^/v8/favorites/[1-9]\d*$').hasMatch(path) &&
            (method == 'GET' || method == 'DELETE'));
    // 영화 기록 저장 (Challenge에서만 사용)
    final movieRecord = path == '/v8/movie-records' && method == 'POST';

    return w8Protected || favorites || movieRecord;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 이전 값이 남아 있지 않도록 먼저 지우고, 조건을 만족할 때만 다시 붙임
    options.headers.remove(_header);
    options.extra.remove(_sessionVersionKey);

    if (_isProtected(options)) {
      // 토큰을 읽기 전에 버전을 기록 — 읽는 사이 로그아웃되면 이 요청의 401은 stale로 버려짐
      final version = sessionHandler?.sessionVersion;
      if (version != null) options.extra[_sessionVersionKey] = version;

      String? token;
      try {
        token = await _tokenStorage.readAccessToken();
      } catch (_) {
        // 저장소 읽기 실패 → 토큰 없이 진행 (서버가 401로 응답)
        token = null;
      }
      if (token != null) {
        options.headers[_header] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final version = options.extra[_sessionVersionKey];
    final session = sessionHandler;
    if (session != null &&
        version is int &&
        _isProtected(options) &&
        classifyApiError(err) == ApiErrorKind.sessionExpired) {
      // 버전 비교·중복 방지는 expireSession 안에서 처리 (동시 401은 첫 번째만 반영)
      unawaited(session.expireSession(sessionVersion: version));
    }
    // 오류는 호출한 쪽에도 그대로 전달 — 호출한 쪽은 sessionExpired면 문구 없이 정리만 함
    handler.next(err);
  }
}
