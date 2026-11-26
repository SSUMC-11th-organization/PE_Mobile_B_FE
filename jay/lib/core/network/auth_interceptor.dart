import 'package:dio/dio.dart';
import 'package:jay/storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);
  final TokenStorage _storage;
  // 보호 요청(JWT를 붙일 요청)인지 판단합니다.
  bool _isProtected(RequestOptions options) {
    // MovieLog 서버가 아닌 곳(TMDB 등)에는 JWT를 붙이지 않습니다.
    if (options.uri.host != 'workbook.devnoco.com') return false;
    final path = options.uri.path;
    final method = options.method.toUpperCase();
    // 8주차의 /v7 경로를 /v8로 바꿉니다. 로그인·회원가입·중복 확인은 보호 요청이 아닙니다.
    final w8Protected =
        path == '/v8/members/me' ||
        path == '/v8/ratings' ||
        path.startsWith('/v8/ratings/');
    // 이번 주에 새로 생긴 즐겨찾기: 등록(POST)·목록(GET) / 여부 조회(GET)·해제(DELETE)
    final favorites =
        (path == '/v8/favorites' && (method == 'GET' || method == 'POST')) ||
        (RegExp(r'^/v8/favorites/[1-9]\d*$').hasMatch(path) &&
            (method == 'GET' || method == 'DELETE'));
    // 영화 기록 저장(Challenge에서만 사용)
    final movieRecord = path == '/v8/movie-records' && method == 'POST';

    return w8Protected || favorites || movieRecord;
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isProtected(options)) {
      handler.next(options);
      return;
    }
    options.headers.remove('Authorization');
    try {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      // 토큰이 없어도 요청은 보냅니다. 서버가 AUTH401_2로 응답해야 세션 정리가 동작합니다.
      handler.next(options);
    } catch (_) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: StateError('인증 저장소를 읽지 못했습니다.'),
        ),
      );
    }
  }
}
