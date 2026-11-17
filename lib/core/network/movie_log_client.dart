import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../debug/debug_failure.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

Dio _createDio() {
  return Dio(
    BaseOptions(
      baseUrl: 'https://workbook.devnoco.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
      },
    ),
  );
}

void _addDebugInterceptors(Dio dio) {
  if (!kDebugMode) return;
  // 8주차: 로그인 비밀번호·JWT가 콘솔에 남지 않도록 body 로깅을 끕니다.
  // ponytail: 필요하면 마스킹 인터셉터를 만든 뒤 다시 켠다.
  dio.interceptors.add(
    LogInterceptor(
      requestHeader: false,
      requestBody: false,
      responseHeader: false,
      responseBody: false,
    ),
  );
  // 로그 뒤에 두어 주입된 실패도 로그에 남습니다.
  dio.interceptors.add(DebugFailureInterceptor());
}

/// 공개 요청용: 로그인, 회원가입, 중복 확인. 토큰을 붙이지 않습니다.
Dio createMovieLogClient() {
  final dio = _createDio();
  _addDebugInterceptors(dio);
  return dio;
}

/// 보호 요청용: 내 정보, 평점 등록/수정/삭제. AuthInterceptor가 Bearer를 붙입니다.
Dio createAuthMovieLogClient(TokenStorage storage) {
  final dio = _createDio();
  dio.interceptors.add(AuthInterceptor(storage)); // 로그보다 먼저 등록
  _addDebugInterceptors(dio);
  return dio;
}
