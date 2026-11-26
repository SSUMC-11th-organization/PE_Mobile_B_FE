/// POST /v8/auth/login 요청 body
class LoginRequest {
  const LoginRequest({required this.email, required this.password});
  final String email;
  final String password;

  // 비밀번호는 입력한 문자가 그대로 의미 있으므로 trim하지 않음
  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
  };
}

/// 로그인 성공 응답의 result. v7 명세상 memberId는 담기지 않으므로 파싱하지 않고,
/// JWT payload에 들어 있을 거라고 추정하지도 않음
class LoginResult {
  const LoginResult({required this.nickname, required this.accessToken});
  final String nickname;
  final String accessToken;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      nickname: json['nickname'] as String,
      accessToken: json['accessToken'] as String,
    );
  }
}
