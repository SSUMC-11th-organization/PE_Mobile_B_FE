import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import '../../core/network/movie_log_client.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';
import 'api_response.dart';

// MovieLog v7 평점 API
// - 쓰기(등록/수정/삭제): 보호용 Dio — AuthInterceptor가 MovieLog JWT 첨부. memberId는 어디에도 보내지 않음
// - 조회(GET /v7/members/{memberId}/ratings): 공개용 Dio — 토큰을 붙이지 않음
class RatingApiService {
  // Dio 대신 래퍼 타입으로 받아 공개/보호 Dio가 뒤바뀌지 않게 함
  RatingApiService(
    MovieLogPublicClient publicClient,
    MovieLogAuthClient authClient,
  )   : _publicDio = publicClient.dio,
        _authDio = authClient.dio;

  final Dio _publicDio;
  final Dio _authDio;

  // 공개 조회 — 응답이 배열 그대로이거나 { isSuccess, result: [...] } wrapper인 경우 모두 처리
  Future<List<RatingDto>> fetchMemberRatings(int memberId) async {
    final r = await _publicDio.get('/v7/members/$memberId/ratings');
    Object? list = r.data;
    final data = r.data;
    if (data is Map<String, dynamic>) {
      if (data['isSuccess'] != true) throw const InvalidApiResponseException();
      list = data['result'];
    }
    if (list is! List) throw const InvalidApiResponseException();
    try {
      return list
          .map((e) => e is Map<String, dynamic>
              ? RatingDto.fromJson(e)
              : throw const FormatException('Rating 형식이 올바르지 않습니다.'))
          .toList();
    } on FormatException {
      throw const InvalidApiResponseException();
    }
  }

  // POST /v7/ratings {movieId, score, comment} — result: Rating
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final r = await _authDio.post('/v7/ratings', data: request.toJson());
    return parseCommonResult(r.data, RatingDto.fromJson);
  }

  // PATCH /v7/ratings/{ratingId} {score, comment} — 부분 수정이 아니라 전체 교체
  // comment가 null(후기 지움)이어도 키를 생략하지 않고 항상 score와 함께 보냄 — result: Rating
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    required String? comment,
  }) async {
    final r = await _authDio.patch(
      '/v7/ratings/$ratingId',
      data: <String, dynamic>{'score': score, 'comment': comment},
    );
    return parseCommonResult(r.data, RatingDto.fromJson);
  }

  // DELETE /v7/ratings/{ratingId} — 성공은 200 + isSuccess true (result는 null)
  Future<void> deleteRating(int ratingId) async {
    final r = await _authDio.delete('/v7/ratings/$ratingId');
    final data = r.data;
    if (r.statusCode != 200 ||
        data is! Map<String, dynamic> ||
        data['isSuccess'] != true) {
      throw const InvalidApiResponseException();
    }
  }
}

// 세션 만료(전역 처리) 또는 세션이 바뀐 뒤 늦게 온 응답 — 화면은 문구 없이 진행 중 상태만 해제
class RatingActionCancelled implements Exception {
  const RatingActionCancelled();
}

enum RatingErrorType {
  sessionExpired,
  forbidden,
  alreadyRated,
  notFound,
  validation,
  network,
  other,
}

// 평점 요청 실패를 화면용 안내로 변환한 결과
class RatingErrorInfo {
  const RatingErrorInfo(this.type, this.message, {this.refreshList = false});

  final RatingErrorType type;
  final String message; // sessionExpired면 쓰지 않음
  final bool refreshList; // 목록이 서버와 달라졌을 수 있어 다시 조회해야 하는 경우

  bool get isSilent => type == RatingErrorType.sessionExpired;
}

// classifyApiError(종류) + 평점 전용 code로 분류 — 화면에서 상태코드/코드를 직접 비교하지 않음
// 어떤 경우에도 로그아웃·토큰 삭제를 하지 않음 (세션 만료는 AuthInterceptor가 전역 처리)
RatingErrorInfo describeRatingError(DioException error) {
  final kind = classifyApiError(error);
  if (kind == ApiErrorKind.sessionExpired) {
    return const RatingErrorInfo(RatingErrorType.sessionExpired, '');
  }
  final serverMessage = apiErrorMessage(error);
  switch (apiErrorCode(error)) {
    case 'RATING403_1':
      return RatingErrorInfo(
        RatingErrorType.forbidden,
        serverMessage ?? '본인이 남긴 평점만 수정하거나 삭제할 수 있습니다.',
      );
    case 'RATING409_1':
      return const RatingErrorInfo(
        RatingErrorType.alreadyRated,
        '이미 이 영화에 평점을 남겼습니다. 마이페이지의 "평점 기록"에서 기존 기록을 확인해 주세요.',
        refreshList: true,
      );
    case 'RATING404_1':
      return RatingErrorInfo(
        RatingErrorType.notFound,
        serverMessage ?? '평점을 찾을 수 없습니다. 목록을 새로 불러옵니다.',
        refreshList: true,
      );
    case 'MEMBER404_1':
      return RatingErrorInfo(
        RatingErrorType.notFound,
        serverMessage ?? '회원 정보를 찾을 수 없습니다. 목록을 새로 불러옵니다.',
        refreshList: true,
      );
  }
  return switch (kind) {
    ApiErrorKind.validation => RatingErrorInfo(
        RatingErrorType.validation,
        serverMessage ?? '입력한 내용을 다시 확인해 주세요.',
      ),
    ApiErrorKind.network => const RatingErrorInfo(
        RatingErrorType.network,
        '네트워크 연결을 확인한 뒤 다시 시도해 주세요.',
      ),
    ApiErrorKind.forbidden => RatingErrorInfo(
        RatingErrorType.forbidden,
        serverMessage ?? '권한이 없습니다.',
      ),
    ApiErrorKind.server => const RatingErrorInfo(
        RatingErrorType.other,
        '서버에 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.',
      ),
    _ => RatingErrorInfo(
        RatingErrorType.other,
        serverMessage ?? '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      ),
  };
}
