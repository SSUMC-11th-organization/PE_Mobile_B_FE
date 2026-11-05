// POST /v6/members 요청 본문
class CreateMemberRequest {
  const CreateMemberRequest({
    required this.email,
    required this.password,
    required this.nickname,
  });

  final String email;
  final String password;
  final String nickname;

  // 비밀번호는 공백도 비밀번호의 일부이므로 trim하지 않음
  Map<String, dynamic> toJson() => {
        'email': email.trim(),
        'password': password,
        'nickname': nickname.trim(),
      };
}
