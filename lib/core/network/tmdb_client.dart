import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/tmdb_config.dart';
import 'tmdb_logging_interceptor.dart';

// TMDB 전용 Dio 인스턴스 — baseUrl, 인증 헤더, 기본 언어, 타임아웃, 로깅을 한곳에서 설정
class TmdbClient {
  TmdbClient({Dio? dio}) : dio = dio ?? _createDio();

  final Dio dio;

  static Dio _createDio() {
    final token = TmdbConfig.accessToken;
    if (kDebugMode && token.isEmpty) {
      debugPrint('[TMDB] TMDB_ACCESS_TOKEN이 비어 있습니다. .env를 확인하세요.');
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: TmdbConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'accept': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        queryParameters: {'language': TmdbConfig.language},
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(TmdbLoggingInterceptor());
    }
    return dio;
  }
}
