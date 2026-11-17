// GET /v7/members/me 성공 응답의 result — { email, nickname, createdAt }
// memberId는 계약에 없음 → 읽지 않음
class MemberInfo {
  const MemberInfo({
    required this.email,
    required this.nickname,
    required this.createdAt,
  });

  final String email;
  final String nickname;
  final DateTime createdAt;

  // 계약과 다르면(필드 누락·타입 불일치·ISO 형식 아님) FormatException
  factory MemberInfo.fromJson(Map<String, dynamic> json) {
    final email = json['email'];
    final nickname = json['nickname'];
    final createdAt = json['createdAt'];
    if (email is! String || nickname is! String || createdAt is! String) {
      throw const FormatException('MemberInfo 형식이 올바르지 않습니다.');
    }
    return MemberInfo(
      email: email,
      nickname: nickname,
      createdAt: DateTime.parse(createdAt), // ISO 8601이 아니면 FormatException
    );
  }
}
