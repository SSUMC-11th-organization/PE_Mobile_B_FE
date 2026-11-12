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

/// 회원가입 실패 문구. 400(비밀번호 형식)·409(이메일/닉네임 중복) 모두 서버 message가
/// 사용자에게 보여줄 수 있는 문장이라 그대로 사용
String writeSignUpErrorMessage(DioException error) {
  final data = error.response?.data;
  final common = data is Map<String, dynamic>
      ? CommonResponse<Object?>.fromJson(data, (value) => value)
      : null;
  return common?.message ?? '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}
