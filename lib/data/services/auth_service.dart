import 'package:dio/dio.dart';

import '../../core/network/movie_log_client.dart';
import '../models/auth_models.dart';
import '../models/common_response.dart';
import '../models/member_info.dart';

// 2xx로 왔지만 계약과 다른 응답(isSuccess false, result 누락, result 파싱 실패 등)
// 메시지에 응답 본문·토큰을 담지 않음
class AuthResponseException implements Exception {
  const AuthResponseException();
}

// MovieLog v7 인증 API
// - 로그인: 공개용 Dio (Authorization 없음)
// - 내 정보: 보호용 Dio (AuthInterceptor가 MovieLog JWT 첨부)
class AuthService {
  // 같은 Dio 타입이라 순서가 바뀌지 않도록 클라이언트 래퍼 타입으로 받음
  AuthService(MovieLogPublicClient publicClient, MovieLogAuthClient authClient)
      : _publicDio = publicClient.dio,
        _authDio = authClient.dio;

  final Dio _publicDio; // 로그인 — Authorization 없음
  final Dio _authDio; // 내 정보 — MovieLog JWT 첨부

  // POST /v7/auth/login — CommonResponse<LoginResult>
  Future<LoginResult> login(LoginRequest request) async {
    final r = await _publicDio.post('/v7/auth/login', data: request.toJson());
    return _unwrap(r.data, LoginResult.fromJson);
  }

  // GET /v7/members/me — CommonResponse<MemberInfo>
  // 2xx + isSuccess true + result가 MemberInfo로 파싱될 때만 값을 돌려줌
  Future<MemberInfo> fetchMe() async {
    final r = await _authDio.get('/v7/members/me');
    return _unwrap(r.data, MemberInfo.fromJson);
  }

  T _unwrap<T>(Object? data, T Function(Map<String, dynamic>) fromJson) {
    if (data is! Map<String, dynamic>) throw const AuthResponseException();
    final response = CommonResponse<Map<String, dynamic>>.fromJson(
      data,
      (json) => json is Map<String, dynamic>
          ? json
          : throw const AuthResponseException(),
    );
    final result = response.result;
    if (!response.isSuccess || result == null) {
      throw const AuthResponseException();
    }
    try {
      return fromJson(result);
    } on FormatException {
      throw const AuthResponseException();
    }
  }
}
