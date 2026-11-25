import 'package:dio/dio.dart';
import 'package:jay/core/network/api_error.dart';
import 'package:jay/data/models/common_response.dart';
import 'package:jay/data/models/rating_dto.dart';
import 'package:jay/data/models/rating_request.dart';

// v7 등록·수정 result는 Rating 객체입니다. (v6: ID 또는 null)
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

// 공개 유저별 평점 조회는 wrapper 없이 배열을 그대로 내려줍니다.
List<RatingDto> parseRatingList(Object? data) {
  if (data is! List) throw StateError('평점 목록 응답은 배열이어야 합니다.');
  return data
      .map((value) => RatingDto.fromJson(value as Map<String, dynamic>))
      .toList();
}

/// 유저별 평점 조회(공개)는 publicDio, 등록·수정·삭제(보호)는 authDio로 보냅니다.
/// ViewModel은 어떤 Client를 쓰는지 몰라도 됩니다.
class RatingApiService {
  RatingApiService(this._publicDio, this._authDio);
  final Dio _publicDio;
  final Dio _authDio;

  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _publicDio.get('/v8/members/$memberId/ratings');
    return parseRatingList(response.data); // 공개 조회: 토큰 없음
  }

  // memberId는 path·body·query 어디에도 넣지 않습니다. 사용자는 Authorization 헤더로 식별됩니다.
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final response = await _authDio.post(
      '/v8/ratings',
      data: request.toJson(),
    );
    return parseRatingResult(response.data);
  }

  // PATCH는 부분 수정이 아니라 전체 교체입니다.
  // comment를 생략하면 null로 덮어써지므로 기존 값을 채운 Dialog에서 두 값을 항상 함께 보냅니다.
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

  // v7 삭제 성공은 204가 아니라 result가 null인 200 응답입니다.
  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete('/v8/ratings/$ratingId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

String writeMyRatingsErrorMessage(DioException error) {
  final code = apiErrorCode(error);
  if (code == 'MEMBER404_1') return '존재하지 않는 회원입니다.';
  if (code == 'COMMON400') return 'memberId 형식을 다시 확인해 주세요.';
  return '평점을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
}

/// v7 도메인 오류 code별 안내 문구. 정의되지 않은 code는 서버 message를 우선 사용합니다.
String writeErrorMessage(DioException error) {
  return switch (apiErrorCode(error)) {
    'RATING403_1' => '본인이 작성한 평점만 변경할 수 있어요.',
    'RATING404_1' => '이미 삭제됐거나 존재하지 않는 평점이에요.',
    'RATING409_1' => '이 영화에는 이미 평점을 남겼어요. 기존 기록을 확인해 주세요.',
    'MEMBER404_1' => '회원 정보를 찾을 수 없어요.',
    'AUTH401_2' || 'AUTH401_3' || 'AUTH401_4' => '로그인이 만료됐어요. 다시 로그인해 주세요.',
    _ => apiErrorMessage(error) ?? '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.',
  };
}

bool shouldRefreshAfterRatingError(DioException error) {
  final code = apiErrorCode(error);
  // 403·404는 화면에 남은 목록이 서버 상태와 어긋났다는 뜻이므로 다시 조회해서 맞춥니다.
  return code == 'RATING403_1' || code == 'RATING404_1';
}
