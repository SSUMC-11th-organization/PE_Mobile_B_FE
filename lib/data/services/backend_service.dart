import 'package:dio/dio.dart';

import '../models/member_check_dto.dart';
import '../models/member_rating_dto.dart';

class BackendService {
  const BackendService(this._dio);

  final Dio _dio;

  /// 닉네임 중복 체크 API
  Future<MemberCheckDto> checkNickname(String nickname) async {
    final response = await _dio.get('/members/nickname/$nickname');
    return MemberCheckDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// 이메일 중복 체크 API
  Future<MemberCheckDto> checkEmail(String email) async {
    final response = await _dio.get('/members/email/$email');
    return MemberCheckDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// 회원별 평점 목록 조회 API
  Future<List<MemberRatingDto>> getMemberRatings(int memberId) async {
    final response = await _dio.get('/members/$memberId/ratings');
    final list = response.data as List<dynamic>? ?? const [];
    return list
        .map((item) => MemberRatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
