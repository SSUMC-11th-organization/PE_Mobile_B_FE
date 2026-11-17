import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

// MovieLog(워크북) 서버 전용 Dio — TMDB용 TmdbClient와는 완전히 별개의 인스턴스
// 공개용과 보호용을 서로 다른 Dio 인스턴스로 나눠, 인증 헤더가 필요한 요청만 보호용을 쓰게 함
class MovieLogConfig {
  MovieLogConfig._();

  static const host = 'workbook.devnoco.com';
  static const baseUrl = 'https://$host';
}

BaseOptions _movieLogBaseOptions() => BaseOptions(
      baseUrl: MovieLogConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    );

// 공개용/보호용 Dio 공통 생성 (TMDB Dio와는 별개)
Dio _newMovieLogDio() {
  final dio = Dio(_movieLogBaseOptions());
  return dio;
}

// 공개용 — 로그인, 회원가입, 중복 확인, 공개 조회. Authorization 헤더를 절대 붙이지 않음
class MovieLogPublicClient {
  MovieLogPublicClient({Dio? dio}) : dio = dio ?? _newMovieLogDio();

  final Dio dio;
}

// 보호용 — 내 정보, 평점 쓰기. AuthInterceptor가 MovieLog JWT만 Bearer로 붙이고 세션 만료(401)를 전역 처리
class MovieLogAuthClient {
  MovieLogAuthClient(TokenStorage tokenStorage, {Dio? dio})
      : dio = dio ?? _newMovieLogDio(),
        _interceptor =
            AuthInterceptor(tokenStorage, allowedHost: MovieLogConfig.host) {
    this.dio.interceptors.add(_interceptor);
  }

  final Dio dio;
  final AuthInterceptor _interceptor;

  // 세션 만료를 처리할 대상 연결/해제 (main.dart에서 AuthViewModel 생성 직후 연결)
  void attachSession(SessionExpiryHandler? handler) =>
      _interceptor.sessionHandler = handler;
}
