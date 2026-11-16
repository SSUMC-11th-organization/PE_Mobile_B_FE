// POST /v8/auth/login 요청 본문
// toString을 재정의하지 않음 → 실수로 출력해도 비밀번호가 문자열에 드러나지 않음
class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  // 비밀번호는 공백도 비밀번호의 일부이므로 trim하지 않음
  Map<String, dynamic> toJson() => {
        'email': email.trim(),
        'password': password,
      };
}

// POST /v8/auth/login 성공 응답의 result — { nickname, accessToken }
// toString을 재정의하지 않음 → 토큰이 문자열로 드러나지 않음
class LoginResult {
  const LoginResult({required this.nickname, required this.accessToken});

  final String nickname;
  final String accessToken;

  // 계약과 다르면(필드 누락·타입 불일치·빈 토큰) FormatException
  factory LoginResult.fromJson(Map<String, dynamic> json) {
    final nickname = json['nickname'];
    final accessToken = json['accessToken'];
    if (nickname is! String ||
        accessToken is! String ||
        accessToken.trim().isEmpty) {
      throw const FormatException('LoginResult 형식이 올바르지 않습니다.');
    }
    return LoginResult(nickname: nickname, accessToken: accessToken);
  }
}
