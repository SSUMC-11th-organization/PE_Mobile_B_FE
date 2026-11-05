import 'package:dio/dio.dart';

import '../models/check_result.dart';

// 워크북 회원 닉네임/이메일 중복 확인 (GET /v5/members/...) — true면 사용 가능
class MemberCheckService {
  MemberCheckService(this._dio);

  final Dio _dio;

  Future<bool> checkNickname(String nickname) async {
    final r = await _dio.get(
      '/v5/members/nickname/${Uri.encodeComponent(nickname.trim())}',
    );
    return CheckResult.fromJson(r.data as Map<String, dynamic>).available;
  }

  Future<bool> checkEmail(String email) async {
    final r = await _dio.get(
      '/v5/members/email/${Uri.encodeComponent(email.trim())}',
    );
    return CheckResult.fromJson(r.data as Map<String, dynamic>).available;
  }
}
