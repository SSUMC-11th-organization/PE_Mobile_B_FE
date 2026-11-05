import 'package:dio/dio.dart';

import '../models/rating_dto.dart';

// 워크북 평점 API — 워크북 Dio(createMovieLogClient)를 주입받아 사용
class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final r = await _dio.get('/v5/members/$memberId/ratings');
    return (r.data as List<dynamic>)
        .map((e) => RatingDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// 평점 목록 요청 실패를 화면 문구로 변환
String writeMyRatingsErrorMessage(DioException error) {
  final s = error.response?.statusCode;
  if (s == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (s == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}
