import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// 디버그 빌드에서만 TMDB 요청/응답을 콘솔에 출력 — Authorization 헤더는 항상 마스킹
class TmdbLoggingInterceptor extends Interceptor {
  static const _tag = '[TMDB]';
  static const _sensitiveHeaders = {'authorization'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('$_tag → ${options.method} ${options.uri}');
      debugPrint('$_tag   headers: ${_maskHeaders(options.headers)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '$_tag ← ${response.statusCode} ${response.requestOptions.method} '
        '${response.requestOptions.uri.path}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '$_tag ✕ ${err.response?.statusCode ?? '-'} ${err.requestOptions.method} '
        '${err.requestOptions.uri.path} (${err.type.name}) ${err.message ?? ''}',
      );
    }
    handler.next(err);
  }

  // 원본 헤더는 그대로 두고, 출력용 사본에서만 민감한 값을 가림
  Map<String, dynamic> _maskHeaders(Map<String, dynamic> headers) {
    return headers.map((key, value) {
      if (_sensitiveHeaders.contains(key.toLowerCase())) {
        return MapEntry(key, 'Bearer ****');
      }
      return MapEntry(key, value);
    });
  }
}
