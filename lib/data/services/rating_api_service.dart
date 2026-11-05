import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

// 워크북 평점 API — 워크북 Dio(createMovieLogClient)를 주입받아 사용
class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    // v6도 이 API는 CommonResponse로 감싸지 않은 배열을 그대로 반환
    final r = await _dio.get('/v6/members/$memberId/ratings');
    return (r.data as List<dynamic>)
        .map((e) => RatingDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // POST /v6/members/{memberId}/ratings — 성공은 201만 인정, result(ratingId)는 사용하지 않음
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final r = await _dio.post(
      '/v6/members/$memberId/ratings',
      data: request.toJson(),
    );
    if (r.statusCode != 201) {
      throw StateError('평점을 등록하지 못했습니다. (응답 코드 ${r.statusCode})');
    }
  }
}

// 평점 목록 요청 실패를 화면 문구로 변환
String writeMyRatingsErrorMessage(DioException error) {
  final s = error.response?.statusCode;
  if (s == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (s == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}

// 공통 실패 문구 — 응답 본문이 CommonResponse 형태면 서버 message, 없으면 기본 문구
String writeErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is Map<String, dynamic>) {
    final message = CommonResponse<Object?>.fromJson(data, (json) => json)
        .message
        .trim();
    if (message.isNotEmpty) return message;
  }
  return '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}
