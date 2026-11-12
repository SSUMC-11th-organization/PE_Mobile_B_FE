import 'package:flutter/foundation.dart';

/// 회원가입 결과의 memberId를 앱 전체에서 공유하는 학습용 세션.
/// 메모리에만 있어 앱을 재시작하면 사라지고, memberId를 안다는 것이 인증은 아님 (JWT 주차에 토큰으로 전환)
class LearningMemberSession extends ChangeNotifier {
  int? memberId;

  void setMemberId(int id) {
    memberId = id;
    notifyListeners();
  }

  void clear() {
    memberId = null;
    notifyListeners();
  }
}
