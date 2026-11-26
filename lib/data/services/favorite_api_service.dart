import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/favorite_check_dto.dart';
import '../models/favorite_response_dto.dart';

/// /v8/favorites 호출. 보호 Client(AuthInterceptor 등록)를 받습니다.
class FavoriteApiService {
  FavoriteApiService(this._dio);

  final Dio _dio;

  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    final response =
        await _dio.post('/v8/favorites', data: {'movieId': movieId});
    return CommonResponse<FavoriteResponseDto>.fromJson(
      response.data as Map<String, dynamic>,
      FavoriteResponseDto.fromJson,
    ).result!;
  }

  Future<List<FavoriteResponseDto>> fetchMyFavorites() async {
    final response = await _dio.get('/v8/favorites');
    return CommonResponse<List<FavoriteResponseDto>>.fromJson(
          response.data as Map<String, dynamic>,
          (value) => (value as List<dynamic>)
              .map(FavoriteResponseDto.fromJson)
              .toList(),
        ).result ??
        const [];
  }

  Future<FavoriteCheckDto> checkFavorite({required int movieId}) async {
    final response = await _dio.get('/v8/favorites/$movieId');
    return CommonResponse<FavoriteCheckDto>.fromJson(
      response.data as Map<String, dynamic>,
      (value) => FavoriteCheckDto.fromJson(value, movieId: movieId),
    ).result!;
  }

  /// 해제는 200 + result null입니다. 예외가 없으면 성공입니다.
  Future<void> deleteFavorite({required int movieId}) async {
    await _dio.delete('/v8/favorites/$movieId');
  }
}
