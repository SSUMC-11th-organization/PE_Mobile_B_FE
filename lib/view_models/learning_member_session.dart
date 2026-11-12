import 'package:flutter/foundation.dart';

// 학습용 회원 세션 — 회원가입으로 받은 memberId를 앱 실행 중 메모리에만 보관 (로그인/토큰 아님)
class LearningMemberSession extends ChangeNotifier {
  int? _memberId;

  int? get memberId => _memberId;

  void setMemberId(int memberId) {
    _memberId = memberId;
    notifyListeners();
  }

  void clear() {
    _memberId = null;
    notifyListeners();
  }
}
