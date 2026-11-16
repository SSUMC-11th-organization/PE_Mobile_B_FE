import 'package:dio/dio.dart';

/// 실패 응답 body({ isSuccess, code, message, result })에서 code를 꺼냄.
/// v7부터는 문구가 아니라 code(AUTH401_2, RATING409_1 등)로 다음 행동을 정함
String? apiErrorCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final code = data['code'];
  return code is String ? code : null;
}

/// 서버가 보낸 message. COMMON400처럼 그대로 보여줄 수 있는 문장일 때 사용
String? apiErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final message = data['message'];
  return message is String ? message : null;
}

/// 보호 요청에서 토큰이 없음(2)·무효(3)·만료(4) → 현재 세션을 더 쓸 수 없음.
/// 로그인 입력 오류인 AUTH401_1은 포함하지 않음 (세션 만료가 아니라 Form 오류)
bool isSessionExpiredCode(String? code) {
  return code == 'AUTH401_2' || code == 'AUTH401_3' || code == 'AUTH401_4';
}
