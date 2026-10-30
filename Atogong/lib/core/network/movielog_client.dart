import 'package:dio/dio.dart';

/// MovieLog 자체 백엔드용 Client. TMDB와 인증 방식이 달라 Client를 분리
Dio createMovieLogClient() {
  return Dio(
    BaseOptions(
      // Android 에뮬레이터에서 호스트 PC의 localhost는 10.0.2.2
      baseUrl: 'http://10.0.2.2:8080',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'accept': 'application/json'},
    ),
  );
}
