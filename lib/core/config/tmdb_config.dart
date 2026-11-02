import 'package:flutter_dotenv/flutter_dotenv.dart';

// TMDB API 설정값 — 토큰은 .env에서만 읽고 코드에는 절대 적지 않음
class TmdbConfig {
  TmdbConfig._(); // 인스턴스 생성 막기 — TmdbConfig.xxx로만 사용

  static const baseUrl = 'https://api.themoviedb.org/3';
  static const imageBaseUrl = 'https://image.tmdb.org/t/p';
  static const posterSize = 'w500';
  static const language = 'ko-KR';

  static const _accessTokenKey = 'TMDB_ACCESS_TOKEN';

  // v4 "API 읽기 액세스 토큰" (Bearer). 비어 있으면 요청은 401로 실패함
  static String get accessToken =>
      dotenv.maybeGet(_accessTokenKey)?.trim() ?? '';

  static bool get hasAccessToken => accessToken.isNotEmpty;

  // poster_path(예: /abc.jpg) → 전체 이미지 URL. 포스터가 없으면 null
  static String? posterUrl(String? posterPath) {
    if (posterPath == null || posterPath.isEmpty) return null;
    return '$imageBaseUrl/$posterSize$posterPath';
  }
}
