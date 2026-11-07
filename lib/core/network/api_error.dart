import 'package:dio/dio.dart';

// MovieLog 서버 실패 응답({ "isSuccess", "code", "message", "result" })에서 값을 꺼내는 공통 함수
// 응답이 없거나(네트워크 오류 등) 형식이 다르면 null — 기본 문구는 호출하는 쪽에서 정함

// 예: COMMON401, COMMON404, MEMBER409 …
String? apiErrorCode(DioException error) => _readString(error, 'code');

// 서버가 내려준 사용자용 안내 문구
String? apiErrorMessage(DioException error) => _readString(error, 'message');

// 응답 자체를 받지 못한 실패 (타임아웃·연결 오류) — 재시도 안내용
bool isNetworkError(DioException error) => switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        true,
      _ => false,
    };

String? _readString(DioException error, String key) {
  final data = error.response?.data;
  if (data is! Map) return null;
  final value = data[key];
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
