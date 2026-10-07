import '../models/movie.dart';

/// 영화 데이터를 불러올 때의 상태(모드)를 나타내는 열거형입니다.
/// 과제 인증 시 성공(success), 빈 목록(empty), 실패(failure) 상황을 테스트하기 위해 사용합니다.
enum MovieLoadMode { success, empty, failure }

/// 영화 로드 실패 시 던질 커스텀 예외(Exception) 클래스입니다.
class MovieLoadException implements Exception {
  const MovieLoadException(this.message);

  final String message;

  @override
  String toString() => 'MovieLoadException: $message';
}

/// 가짜(Mock) 영화 데이터 서비스입니다.
/// 실제 서버 API 대신 비동기 통신(1초 대기)을 흉내 내어 영화 데이터를 반환합니다.
class FakeMovieService {
  const FakeMovieService();

  /// 영화 목록을 비동기(Future)로 불러옵니다.
  /// [mode]에 따라 성공, 빈 목록, 오류를 시뮬레이션할 수 있습니다.
  Future<List<Movie>> fetchMovies({
    MovieLoadMode mode = MovieLoadMode.success,
  }) async {
    // 5주차에는 이 부분이 실제 백엔드 서버(Swagger API) 호출로 교체됩니다.
    // TODO(5주차 유저별 평점 조회 API)

    // 서버와 통신하는 데 1초가 걸린다고 가정하고 1초간 기다립니다.
    await Future<void>.delayed(const Duration(seconds: 1));

    // 모드에 따라 알맞은 결과를 반환하거나 에러를 발생시킵니다.
    return switch (mode) {
      MovieLoadMode.success => movies,
      MovieLoadMode.empty => const <Movie>[],
      MovieLoadMode.failure =>
        throw const MovieLoadException('영화를 불러오지 못했습니다.'),
    };
  }
}
