import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

BaseOptions _movieLogOptions() {
  return BaseOptions(
    baseUrl: 'https://workbook.devnoco.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  );
}

/// MovieLog 자체 백엔드(워크북 서버)용 Client. TMDB와 baseUrl·헤더가 달라 Client를 분리.
/// 공개 요청용 (6주차 코드 유지): 로그인, 회원가입, 중복 체크, 유저별 평점 조회 / Interceptor 없음
Dio createMovieLogClient() {
  return Dio(_movieLogOptions());
}

/// 보호 요청용 (8주차 추가): 내 정보, 평점 등록·수정·삭제 / AuthInterceptor가 Bearer 토큰을 붙임.
/// Interceptor는 화면이나 메서드가 아니라 이 Client 하나에 등록
Dio createAuthMovieLogClient(TokenStorage storage) {
  final dio = Dio(_movieLogOptions());
  dio.interceptors.add(AuthInterceptor(storage));
  return dio;
}
