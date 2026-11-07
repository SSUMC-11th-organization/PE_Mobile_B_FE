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

// 공개용 — 로그인, 회원가입, 중복 확인, 공개 조회. Authorization 헤더를 절대 붙이지 않음
class MovieLogPublicClient {
  MovieLogPublicClient({Dio? dio}) : dio = dio ?? Dio(_movieLogBaseOptions());

  final Dio dio;
}

// 보호용 — 내 정보, 평점 쓰기. AuthInterceptor가 MovieLog JWT만 Bearer로 붙임
class MovieLogAuthClient {
  MovieLogAuthClient(TokenStorage tokenStorage, {Dio? dio})
      : dio = dio ?? Dio(_movieLogBaseOptions()) {
    this.dio.interceptors.add(
          AuthInterceptor(tokenStorage, allowedHost: MovieLogConfig.host),
        );
  }

  final Dio dio;
}
