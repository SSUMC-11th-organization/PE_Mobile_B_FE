import 'package:flutter/material.dart';

/// 이 앱에서 회원가입했을 때 받은 memberId를 기억합니다. (공개 유저별 평점 GET에만 사용)
///
/// v7 로그인·내 정보 응답에는 memberId가 없으므로, 가입 때 받은 email과
/// 현재 로그인한 회원의 email이 같을 때만 이 memberId를 사용합니다.
/// 다른 계정으로 로그인하면 남의 평점 목록을 내 것처럼 보여주지 않습니다.
class LearningMemberSession extends ChangeNotifier {
  int? memberId;
  String? email;

  void setMember({required int id, required String email}) {
    memberId = id;
    this.email = email.trim().toLowerCase();
    notifyListeners();
  }

  /// 현재 로그인 회원의 email과 일치할 때만 memberId를 돌려줍니다.
  int? memberIdFor(String? loggedInEmail) {
    if (loggedInEmail == null || email == null) return null;
    return loggedInEmail.trim().toLowerCase() == email ? memberId : null;
  }

  void clear() {
    memberId = null;
    email = null;
    notifyListeners();
  }
}
