/// v6 공통 응답 형식 { isSuccess, code, message, result }.
/// 회원가입·평점 쓰기 API의 성공 응답과 v6의 모든 실패 응답이 이 모양.
/// result는 API마다 달라 제네릭 T로 받고, 값이 없거나 실패 응답이면 null
class CommonResponse<T> {
  const CommonResponse({
    required this.isSuccess,
    required this.code,
    required this.message,
    this.result,
  });

  final bool isSuccess;
  final String code;
  final String message;
  final T? result;

  factory CommonResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? value) parseResult,
  ) {
    final rawResult = json['result'];
    return CommonResponse<T>(
      isSuccess: json['isSuccess'] as bool,
      code: json['code'] as String,
      message: json['message'] as String,
      result: rawResult == null ? null : parseResult(rawResult),
    );
  }
}
