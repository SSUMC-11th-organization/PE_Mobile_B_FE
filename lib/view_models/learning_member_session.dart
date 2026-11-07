import 'package:flutter/foundation.dart';

// 학습용 회원 세션 — 회원가입(v6) 응답의 memberId를 앱 실행 중 메모리에만 보관 (로그인/토큰 아님)
// 평점 기록 화면에서 공개 조회(GET /v7/members/{memberId}/ratings)에만 사용
// logout / expireSession 때 비우고, 가입한 이메일과 다른 계정으로 로그인하면 비움
class LearningMemberSession extends ChangeNotifier {
  int? _memberId;
  String? _email; // 가입 시 이메일 — 로그인 계정과 같은 사람인지 비교용

  int? get memberId => _memberId;

  void setMemberId(int memberId, {String? email}) {
    _memberId = memberId;
    _email = _normalize(email);
    notifyListeners();
  }

  // 로그인한 이메일이 가입 이메일과 다르면(또는 알 수 없으면) 다른 사용자로 보고 비움
  void clearIfEmailDiffers(String loginEmail) {
    if (_memberId == null) return;
    if (_email != null && _email == _normalize(loginEmail)) return;
    clear();
  }

  void clear() {
    if (_memberId == null && _email == null) return;
    _memberId = null;
    _email = null;
    notifyListeners();
  }

  static String? _normalize(String? email) => email?.trim().toLowerCase();
}
