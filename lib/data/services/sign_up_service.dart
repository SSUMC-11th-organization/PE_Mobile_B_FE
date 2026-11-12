import 'package:dio/dio.dart';

import '../models/check_result.dart';
import '../models/common_response.dart';
import '../models/create_member_request.dart';
import '../models/sign_up_models.dart';

// 워크북 회원가입 관련 API (v6) — 닉네임/이메일 중복 확인(true면 사용 가능), 회원가입 POST
class SignUpService {
  SignUpService(this._dio);

  final Dio _dio;

  Future<bool> checkNickname(String nickname) async {
    final r = await _dio.get(
      '/v6/members/nickname/${Uri.encodeComponent(nickname.trim())}',
    );
    return CheckResult.fromJson(r.data as Map<String, dynamic>).available;
  }

  Future<bool> checkEmail(String email) async {
    final r = await _dio.get(
      '/v6/members/email/${Uri.encodeComponent(email.trim())}',
    );
    return CheckResult.fromJson(r.data as Map<String, dynamic>).available;
  }

  // POST /v6/members — 성공 시 201 + CommonResponse<SignUpResult>
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    final r = await _dio.post('/v6/members', data: request.toJson());
    return CommonResponse.fromJson(
      r.data as Map<String, dynamic>,
      (json) => SignUpResult.fromJson(json as Map<String, dynamic>),
    );
  }
}

// 회원가입 실패를 화면 문구로 변환 — 서버 message가 있으면 그대로, 없으면 기본 문구
String writeSignUpErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is Map<String, dynamic>) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) return message;
  }
  return '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}
