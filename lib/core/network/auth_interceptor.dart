import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// MovieLog 보호 API에만 `Authorization: Bearer {JWT}`를 붙입니다.
/// 401 처리(세션 정리)는 상태를 가진 AuthViewModel의 일이므로 여기서 하지 않습니다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final TokenStorage _storage;

  bool _isProtected(RequestOptions options) {
    final path = options.uri.path;
    return options.uri.host == 'workbook.devnoco.com' &&
        (path == '/v7/members/me' ||
            path == '/v7/ratings' ||
            path.startsWith('/v7/ratings/'));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isProtected(options)) {
      handler.next(options);
      return;
    }
    options.headers.remove('Authorization'); // 이전 요청의 토큰을 재사용하지 않습니다.
    try {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (_) {
      // 기기 저장소 실패는 서버 401과 다른 오류입니다.
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.unknown,
        error: StateError('인증 저장소를 읽지 못했습니다.'),
      ));
    }
  }
}
