class CreateMemberRequest {
  final String email;
  final String password;
  final String nickname;

  const CreateMemberRequest({
    required this.email,
    required this.password,
    required this.nickname,
  });

  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
    'nickname': nickname.trim(),
  };
}
