import 'package:dio/dio.dart';

import '../../core/network/movie_log_client.dart';
import '../models/member_info.dart';
import 'api_response.dart';

// MovieLog v7 내 정보 API — 보호용 Dio (AuthInterceptor가 MovieLog JWT 첨부)
// 응답 result가 MemberInfo로 파싱되지 않으면 InvalidApiResponseException
class MemberApiService {
  // Dio 대신 래퍼 타입으로 받아 공개용 Dio가 잘못 들어오지 않게 함
  MemberApiService(MovieLogAuthClient authClient) : _dio = authClient.dio;

  final Dio _dio;

  // GET /v8/members/me — CommonResponse<MemberInfo>
  Future<MemberInfo> fetchMe() async {
    final r = await _dio.get('/v8/members/me');
    return parseCommonResult(r.data, MemberInfo.fromJson);
  }

  // PATCH /v8/members/me { "nickname": ... } — CommonResponse<MemberInfo>
  Future<MemberInfo> updateNickname(String nickname) async {
    final r = await _dio.patch(
      '/v8/members/me',
      data: <String, dynamic>{'nickname': nickname},
    );
    return parseCommonResult(r.data, MemberInfo.fromJson);
  }
}
