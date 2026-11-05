// 워크북 v6 공통 응답 — { "isSuccess", "code", "message", "result" }
class CommonResponse<T> {
  const CommonResponse({
    required this.isSuccess,
    required this.code,
    required this.message,
    this.result,
  });

  final bool isSuccess;
  final String code; // 예: COMMON201, COMMON400, COMMON409
  final String message;
  final T? result; // 실패 응답이나 result가 없는 API는 null

  factory CommonResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromResult,
  ) {
    final result = json['result'];
    return CommonResponse(
      isSuccess: json['isSuccess'] as bool? ?? false,
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
      result: result == null ? null : fromResult(result),
    );
  }
}
