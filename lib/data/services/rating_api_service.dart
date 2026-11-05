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

  // PATCH /v6/members/{memberId}/ratings/{ratingId} — score·comment 전체 교체 방식
  // comment가 null(후기 지움)이어도 키를 생략하지 않고 명시적으로 보냄
  // 성공 응답의 result는 사용하지 않음
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    await _dio.patch(
      '/v6/members/$memberId/ratings/$ratingId',
      data: <String, dynamic>{'score': score, 'comment': comment},
    );
  }

  // DELETE /v6/members/{memberId}/ratings/{ratingId} — 성공은 본문 없는 204만 인정
  // 응답 본문은 파싱하지 않도록 plain으로 받고, data는 읽지 않음
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    final r = await _dio.delete(
      '/v6/members/$memberId/ratings/$ratingId',
      options: Options(responseType: ResponseType.plain),
    );
    if (r.statusCode != 204) {
      throw StateError('평점을 삭제하지 못했습니다. (응답 코드 ${r.statusCode})');
    }
  }
}

// 수정/삭제 실패 중 목록이 이미 서버와 달라졌을 가능성이 있는 경우(권한 없음/이미 없음) → 목록 새로고침 필요
bool shouldRefreshAfterRatingError(DioException error) {
  final data = error.response?.data;
  if (data is! Map) return false;
  final code = data['code'];
  return code == 'COMMON403' || code == 'COMMON404';
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
