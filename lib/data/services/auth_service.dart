import 'package:dio/dio.dart';

import '../../core/network/movie_log_client.dart';
import '../models/auth_models.dart';
import 'api_response.dart';

// MovieLog v7 인증 API — 로그인은 공개용 Dio (Authorization 없음)
// 내 정보 조회·수정은 MemberApiService(보호용 Dio)에서 담당
class AuthService {
  // Dio 대신 래퍼 타입으로 받아 보호용 Dio가 잘못 들어오지 않게 함
  AuthService(MovieLogPublicClient publicClient) : _publicDio = publicClient.dio;

  final Dio _publicDio;

  // POST /v7/auth/login — CommonResponse<LoginResult>
  // 계약과 다른 응답이면 InvalidApiResponseException
  Future<LoginResult> login(LoginRequest request) async {
    final r = await _publicDio.post('/v7/auth/login', data: request.toJson());
    return parseCommonResult(r.data, LoginResult.fromJson);
  }
}
