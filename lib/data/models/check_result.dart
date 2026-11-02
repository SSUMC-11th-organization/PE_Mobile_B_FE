// 워크북 중복 확인 응답 — { "available": true/false }
class CheckResult {
  const CheckResult({required this.available});

  final bool available;

  factory CheckResult.fromJson(Map<String, dynamic> json) =>
      CheckResult(available: json['available'] as bool);
}
