import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

RatingDto parseRatingResult(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw StateError('평점 응답 형식이 올바르지 않습니다.');
  }
  final common = CommonResponse<RatingDto>.fromJson(
    data,
    (value) => RatingDto.fromJson(value as Map<String, dynamic>),
  );
  final rating = common.result;
  if (rating == null) throw StateError('평점 result가 없습니다.');
  return rating;
}

List<RatingDto> parseRatingList(Object? data) {
  if (data is! List) throw StateError('평점 목록 응답은 배열이어야 합니다.');
  return data
      .map((value) => RatingDto.fromJson(value as Map<String, dynamic>))
      .toList();
}

/// 조회(공개)는 publicDio, 등록·수정·삭제(보호)는 authDio를 씁니다.
class RatingApiService {
  RatingApiService(this._publicDio, this._authDio);

  final Dio _publicDio;
  final Dio _authDio;

  /// 공개 API: memberId path를 유지하며 토큰이 필요 없습니다.
  /// v7에는 "내 memberId"를 알 방법이 없어 현재 화면에서는 사용하지 않습니다.
  Future<List<RatingDto>> fetchMemberRatings(int memberId) async {
    final response = await _publicDio.get('/v8/members/$memberId/ratings');
    return parseRatingList(response.data);
  }

  /// 200/201 + wrapper(result = Rating). memberId는 보내지 않습니다.
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final response =
        await _authDio.post('/v8/ratings', data: request.toJson());
    return parseRatingResult(response.data);
  }

  /// PATCH는 전체 교체입니다. comment를 생략하면 기존 후기가 null로 덮이므로 항상 함께 보냅니다.
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final response = await _authDio.patch(
      '/v8/ratings/$ratingId',
      data: {'score': score, 'comment': comment},
    );
    return parseRatingResult(response.data);
  }

  /// v7 삭제 성공은 204가 아니라 result가 null인 200입니다.
  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete('/v8/ratings/$ratingId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 쓰기 오류를 코드별 사용자 문구로 바꿉니다. 403·409는 안내만 하고 로그아웃하지 않습니다.
String ratingErrorMessage(DioException error) {
  final code = apiErrorCode(error);
  if (isSessionExpiredCode(code)) return '로그인이 만료됐어요. 다시 로그인해 주세요.';
  switch (code) {
    case 'RATING403_1':
      return '본인이 작성한 평점만 수정·삭제할 수 있어요.';
    case 'RATING409_1':
      return '이미 이 영화에 평점을 남겼어요.';
    case 'RATING404_1':
      return '존재하지 않는 평점이에요.';
    case 'MEMBER404_1':
      return '회원 정보를 찾을 수 없어요.';
    case 'COMMON400':
      return apiErrorMessage(error) ?? '입력값을 확인해 주세요.';
    default:
      return '요청에 실패했어요. 잠시 후 다시 시도해 주세요.';
  }
}
