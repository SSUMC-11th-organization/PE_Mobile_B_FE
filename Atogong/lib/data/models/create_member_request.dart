/// POST /v6/members 요청 body. Dart 객체 → JSON 방향이라 toJson만 가짐
class CreateMemberRequest {
  const CreateMemberRequest({
    required this.email,
    required this.password,
    required this.nickname,
  });

  final String email;
  final String password;
  final String nickname;

  // 비밀번호는 입력한 문자가 그대로 의미 있으므로 trim하지 않음
  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
    'nickname': nickname.trim(),
  };
}
