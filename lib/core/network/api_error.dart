import 'package:dio/dio.dart';

// MovieLog 서버 실패 응답({ "isSuccess", "code", "message", "result" })에서 값을 꺼내는 공통 함수
// 응답이 없거나(네트워크 오류 등) 형식이 다르면 null — 기본 문구는 호출하는 쪽에서 정함

// 예: COMMON401, COMMON404, MEMBER409 …
String? apiErrorCode(DioException error) => _readString(error, 'code');

// 서버가 내려준 사용자용 안내 문구
String? apiErrorMessage(DioException error) => _readString(error, 'message');

String? _readString(DioException error, String key) {
  final data = error.response?.data;
  if (data is! Map) return null;
  final value = data[key];
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
