import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

// MovieLog 보호용 Dio에만 붙이는 인터셉터 — 요청마다 저장소에서 MovieLog JWT를 읽어 Bearer로 첨부
// - TMDB Dio, MovieLog 공개용 Dio에는 붙이지 않음
// - 토큰 값은 로그로 남기지 않음
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage, {required this.allowedHost});

  final TokenStorage _tokenStorage;

  // JWT를 보낼 수 있는 유일한 호스트 (MovieLog 서버) — 다른 호스트로 가는 요청엔 첨부하지 않음
  final String allowedHost;

  static const _header = 'Authorization';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 이전 값이 남아 있지 않도록 먼저 지우고, 조건을 만족할 때만 다시 붙임
    options.headers.remove(_header);

    if (options.uri.host == allowedHost) {
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
}
