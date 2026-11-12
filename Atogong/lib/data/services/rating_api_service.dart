import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

/// 평점 조회·등록·수정·삭제 (v6). API마다 성공 응답 모양이 달라 각각 계약에 맞춰 처리
/// 조회: 200 + 직접 배열 / 등록: 201 + wrapper / 수정: 200 + result null / 삭제: 204 + body 없음
class RatingApiService {
  RatingApiService(this._dio);
  final Dio _dio;

  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get('/v6/members/$memberId/ratings');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final response = await _dio.post(
      '/v6/members/$memberId/ratings',
      data: request.toJson(),
    );
    // 201만 성공으로 처리. result(ratingId)는 계약이 확정되지 않아 파싱하지 않고, 등록 후 GET으로 확인
    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 등록 응답: ${response.statusCode}');
    }
  }

  /// PATCH지만 score는 필수. comment를 생략하면 기존 후기가 null로 덮이므로 유지하려면 기존 값을 그대로 보냄
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    await _dio.patch(
      '/v6/members/$memberId/ratings/$ratingId',
      data: {'score': score, 'comment': comment},
    );
  }

  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    final response = await _dio.delete(
      '/v6/members/$memberId/ratings/$ratingId',
    );
    // 204는 body가 없으므로 response.data를 JSON으로 파싱하지 않음
    if (response.statusCode != 204) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 400(형식)·404(없는 회원)·그 외를 다른 문구로 구분
String writeMyRatingsErrorMessage(DioException error) {
  final status = error.response?.statusCode;
  if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (status == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}

/// 쓰기(등록·수정·삭제) 실패 문구. 같은 COMMON404라도 등록은 "유저", 수정·삭제는 "평점"을 가리키므로
/// code로 문구를 새로 만들지 않고 서버 message를 그대로 사용
String writeErrorMessage(DioException error) {
  final data = error.response?.data;
  final common = data is Map<String, dynamic>
      ? CommonResponse<Object?>.fromJson(data, (value) => value)
      : null;
  return common?.message ?? '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

/// code는 문구가 아니라 다음 UI 행동(목록을 다시 조회할지)을 정하는 데만 사용.
/// 403·404는 화면의 목록이 서버 상태와 어긋났다는 뜻이라 재조회, 400·409는 값만 고치면 되므로 재조회 안 함
bool shouldRefreshAfterRatingError(DioException error) {
  final data = error.response?.data;
  final code = data is Map<String, dynamic> ? data['code'] as String? : null;
  return code == 'COMMON403' || code == 'COMMON404';
}
