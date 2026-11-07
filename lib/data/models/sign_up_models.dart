// POST /v6/members 성공 응답의 result — { memberId, email, nickname }
class SignUpResult {
  const SignUpResult({this.memberId, required this.email, required this.nickname});

  final int? memberId; // 응답에 없으면 null → 가입 완료로 처리하지 않음
  final String email;
  final String nickname;

  factory SignUpResult.fromJson(Map<String, dynamic> json) => SignUpResult(
        memberId: (json['memberId'] as num?)?.toInt(),
        email: json['email'] as String? ?? '',
        nickname: json['nickname'] as String? ?? '',
      );
}
