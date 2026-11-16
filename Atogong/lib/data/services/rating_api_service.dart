import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

/// v7 등록·수정 성공 응답은 공통 형식으로 감싸져 오고 result가 Rating 객체 (v6: ID 또는 null)
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

/// 유저별 평점 조회 성공 응답은 v7에서도 공통 형식 없이 배열 그대로
List<RatingDto> parseRatingList(Object? data) {
  if (data is! List) throw StateError('평점 목록 응답은 배열이어야 합니다.');
  return data
      .map((value) => RatingDto.fromJson(value as Map<String, dynamic>))
      .toList();
}

/// 평점 API (v7). 메서드에 따라 다른 Client를 사용:
/// 유저별 조회는 공개 API라 공개용 Client, 등록·수정·삭제는 보호 API라 보호용 Client(Interceptor가 Bearer 부착).
/// 쓰기 요청의 path·body 어디에도 memberId가 없고, 누구의 요청인지는 서버가 토큰으로 판단
class RatingApiService {
  RatingApiService(this._publicDio, this._authDio);
  final Dio _publicDio;
  final Dio _authDio;

  /// 공개 조회: 직접 배열, 토큰 없음.
  /// v7 로그인 응답에 memberId가 없어 "내가 등록한 평점" 화면에서는 호출하지 않음 (SessionRatings 참고)
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _publicDio.get('/v7/members/$memberId/ratings');
    return parseRatingList(response.data);
  }

  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final response = await _authDio.post('/v7/ratings', data: request.toJson());
    return parseRatingResult(response.data);
  }

  /// PATCH지만 부분 수정이 아니라 전체 교체. comment를 생략하면 기존 후기가 null로 덮이므로
  /// Dialog를 열 때 기존 score·comment를 채우고 항상 두 값을 함께 보냄
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final response = await _authDio.patch(
      '/v7/ratings/$ratingId',
      data: {'score': score, 'comment': comment},
    );
    return parseRatingResult(response.data);
  }

  /// v6의 204(body 없음)와 달리 v7 삭제 성공은 200 + result null
  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete('/v7/ratings/$ratingId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 쓰기(등록·수정·삭제) 실패 문구. 400(COMMON400)·403(RATING403_1)·404(RATING404_1)·409(RATING409_1) 모두
/// 서버 message가 사용자에게 보여줄 수 있는 문장이라 그대로 사용. 다음 행동은 문구가 아니라 code로 결정
String writeErrorMessage(DioException error) {
  if (error.response == null) return '네트워크 상태를 확인하고 다시 시도해 주세요.';
  return apiErrorMessage(error) ?? '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}
