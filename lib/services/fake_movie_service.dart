import '../data/mock_movies.dart';
import '../models/movie.dart';

enum MovieLoadMode { success, empty, failure }

class MovieLoadException implements Exception {
  const MovieLoadException(this.message);
  final String message;
}

// API 연결 전 Mock Future — 5주차에 실제 API Service로 교체 예정
class FakeMovieService {
  const FakeMovieService();

  // TODO(5주차 유저별 평점 조회 API)
  Future<List<Movie>> fetchMovies({
    MovieLoadMode mode = MovieLoadMode.success,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900)); // 최소 800ms Loading 노출

    return switch (mode) {
      MovieLoadMode.success => mockMovies,
      MovieLoadMode.empty => const <Movie>[],
      MovieLoadMode.failure =>
        throw const MovieLoadException('영화를 불러오지 못했습니다.'),
    };
  }
}
