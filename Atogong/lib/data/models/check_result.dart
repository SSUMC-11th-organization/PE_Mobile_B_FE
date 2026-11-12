/// 중복 확인 응답(v5·v6 동일). 공통 Wrapper 없이 { "available": true } 그대로 내려옴
class CheckResult {
  const CheckResult({required this.available});

  final bool available;

  factory CheckResult.fromJson(Map<String, dynamic> json) {
    return CheckResult(available: json['available'] as bool);
  }
}
