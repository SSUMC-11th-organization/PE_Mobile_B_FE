import 'package:dio/dio.dart';

import '../../core/network/movie_log_client.dart';
import '../models/common_response.dart';
import '../models/favorite_check_dto.dart';
import '../models/favorite_response_dto.dart';
import 'api_response.dart';

// MovieLog v8 즐겨찾기 API(/v8/favorites) — 보호용 Dio (AuthInterceptor가 MovieLog JWT 첨부)
// 경로에는 favoriteId가 아니라 TMDB movieId를 넣음
// 오류는 DioException 그대로 전달 (code 구분은 apiErrorCode/classifyApiError로)
class FavoriteApiService {
  // Dio 대신 래퍼 타입으로 받아 공개용 Dio가 잘못 들어오지 않게 함
  FavoriteApiService(MovieLogAuthClient authClient) : _dio = authClient.dio;

  final Dio _dio;

  // POST /v8/favorites { movieId } — 201, result: FavoriteResponseDto
  // 자동 재시도하지 않음 (timeout이어도 서버에서는 등록됐을 수 있음)
  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    final r = await _dio.post(
      '/v8/favorites',
      data: <String, dynamic>{'movieId': movieId},
    );
    return parseCommonResult(r.data, FavoriteResponseDto.fromJson);
  }

  // GET /v8/favorites — 200, result: 배열 (없으면 [])
  Future<List<FavoriteResponseDto>> fetchMyFavorites() async {
    final r = await _dio.get('/v8/favorites');
    final data = r.data;
    if (data is! Map<String, dynamic>) throw const InvalidApiResponseException();
    try {
      final body = CommonResponse<List<FavoriteResponseDto>>.fromJson(
        data,
        (value) {
          if (value is! List) {
            throw const FormatException('result must be a JSON array.');
          }
          return value.map(FavoriteResponseDto.fromJson).toList();
        },
      );
      if (!body.isSuccess) throw const InvalidApiResponseException();
      return body.result ?? const [];
    } on FormatException {
      throw const InvalidApiResponseException();
    }
  }

  // GET /v8/favorites/{movieId} — 200, result: { isFavorite }
  Future<FavoriteCheckDto> checkFavorite({required int movieId}) async {
    final r = await _dio.get('/v8/favorites/$movieId');
    return parseCommonResult(
      r.data,
      (json) => FavoriteCheckDto.fromJson(json, movieId: movieId),
    );
  }

  // DELETE /v8/favorites/{movieId} — 200, result는 null (평점 삭제의 204와 다름)
  // body를 DTO로 파싱하지 않음 → DioException이 없으면 성공
  Future<void> deleteFavorite({required int movieId}) async {
    await _dio.delete('/v8/favorites/$movieId');
  }
}
