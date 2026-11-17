import 'package:dio/dio.dart';

import '../models/member_info.dart';

/// 내 정보 조회·수정 (v7). 둘 다 보호 API라 AuthInterceptor가 등록된 보호용 Client만 받음.
/// path에 memberId가 없고, 누구인지는 서버가 토큰으로 판단
class MemberApiService {
  MemberApiService(this._authDio);
  final Dio _authDio;

  Future<MemberInfo> fetchMe() async {
    final response = await _authDio.get('/v7/members/me');
    return parseMemberInfo(response.data);
  }

  Future<MemberInfo> updateNickname(String nickname) async {
    final response = await _authDio.patch(
      '/v7/members/me',
      data: {'nickname': nickname},
    );
    return parseMemberInfo(response.data);
  }
}
