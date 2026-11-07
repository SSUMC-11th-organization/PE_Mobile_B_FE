import '../models/common_response.dart';

// 2xx로 왔지만 계약과 다른 응답(isSuccess false, result 누락, result 파싱 실패 등)
// 메시지에 응답 본문·토큰을 담지 않음
class InvalidApiResponseException implements Exception {
  const InvalidApiResponseException();
}

// MovieLog v7 성공 응답 { isSuccess, code, message, result }에서 result를 꺼내 T로 파싱
// isSuccess가 true이고 result가 객체이며 fromJson이 성공해야만 값을 돌려줌
T parseCommonResult<T>(
  Object? data,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (data is! Map<String, dynamic>) throw const InvalidApiResponseException();
  final result = CommonResponse<Object?>.fromJson(data, (json) => json);
  final body = result.result;
  if (!result.isSuccess || body is! Map<String, dynamic>) {
    throw const InvalidApiResponseException();
  }
  try {
    return fromJson(body);
  } on FormatException {
    throw const InvalidApiResponseException();
  }
}
