import 'package:dio/dio.dart';

import '../models/check_result.dart';
import '../models/common_response.dart';
import '../models/create_member_request.dart';
import '../models/sign_up_models.dart';

/// 회원가입 관련 API (v6). 6주차 MemberCheckService에 회원가입 POST를 더해 이름 변경
class SignUpService {
  SignUpService(this._dio);
  final Dio _dio;

  // 중복 확인 GET은 v6에서도 성공 시 Wrapper 없이 { "available": true } 그대로
  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get('/v6/members/nickname/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get('/v6/members/email/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  /// POST /v6/members. 성공(201)은 공통 응답으로 감싸져 오므로 한 번 파싱한 뒤 result에서 payload를 읽음
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    final response = await _dio.post('/v6/members', data: request.toJson());

    return CommonResponse<SignUpResult>.fromJson(
      response.data as Map<String, dynamic>,
      (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
    );
  }
}
