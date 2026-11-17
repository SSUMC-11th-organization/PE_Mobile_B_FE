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

// 화면·ViewModel이 상태코드/코드를 직접 비교하지 않도록 오류를 한 종류로 분류
enum ApiErrorKind {
  sessionExpired, // 401 + AUTH401_2/3/4 — 보호 요청의 토큰이 더 이상 유효하지 않음 (전역 처리)
  loginFailed, // 401 + AUTH401_1 — 로그인 자격 증명 불일치 (세션 만료 아님)
  forbidden, // 403
  conflict, // 409
  validation, // 400
  network, // 응답 없음 (타임아웃·연결 오류)
  server, // 5xx
  unknown, // 그 외 (다른 401 코드, 404 등)
}

const _sessionExpiredCodes = {'AUTH401_2', 'AUTH401_3', 'AUTH401_4'};
const _loginFailedCode = 'AUTH401_1';

ApiErrorKind classifyApiError(DioException error) {
  if (isNetworkError(error)) return ApiErrorKind.network;
  final status = error.response?.statusCode;
  if (status == null) return ApiErrorKind.unknown;
  if (status == 401) {
    final code = apiErrorCode(error);
    if (code == _loginFailedCode) return ApiErrorKind.loginFailed;
    if (_sessionExpiredCodes.contains(code)) return ApiErrorKind.sessionExpired;
    return ApiErrorKind.unknown;
  }
  if (status == 403) return ApiErrorKind.forbidden;
  if (status == 409) return ApiErrorKind.conflict;
  if (status == 400) return ApiErrorKind.validation;
  if (status >= 500) return ApiErrorKind.server;
  return ApiErrorKind.unknown;
}

String? _readString(DioException error, String key) {
  final data = error.response?.data;
  if (data is! Map) return null;
  final value = data[key];
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
