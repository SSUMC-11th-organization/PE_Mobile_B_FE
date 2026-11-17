import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../debug/debug_failure.dart';

Dio createMovieLogClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://workbook.devnoco.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
      ),
    );
    // 로그 뒤에 두어 주입된 실패도 로그에 남습니다.
    dio.interceptors.add(DebugFailureInterceptor());
  }

  return dio;
}
