import 'package:dio/dio.dart';

/// 5주차 BE 워크북에서 만든 API 3개 호출
class MovieLogApiService {
  MovieLogApiService(this._dio);
  final Dio _dio;

  /// GET /members/nickname/{nickname} → { "available": true }
  Future<bool> checkNickname(String nickname) async {
    final response = await _dio.get('/members/nickname/$nickname');
    return (response.data as Map<String, dynamic>)['available'] as bool;
  }

  /// GET /members/email/{email} → { "available": true }
  Future<bool> checkEmail(String email) async {
    final response = await _dio.get('/members/email/$email');
    return (response.data as Map<String, dynamic>)['available'] as bool;
  }

  /// GET /members/{memberId}/ratings → [ { ratingId, movieId, score, comment, ... } ]
  Future<List<Map<String, dynamic>>> fetchRatings(int memberId) async {
    final response = await _dio.get('/members/$memberId/ratings');
    return (response.data as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
