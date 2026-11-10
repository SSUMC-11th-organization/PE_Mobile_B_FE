import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 학습용 현재 회원 상태. 인증이 아닙니다(JWT 주차에 교체).
/// 임시 로그인 입력 편의를 위해 마지막 memberId만 기기에 저장합니다(비밀번호는 저장하지 않음).
class LearningMemberSession extends ChangeNotifier {
  static const _lastIdKey = 'last_member_id';

  int? memberId;

  void setMemberId(int id) {
    memberId = id;
    notifyListeners();
    _saveLast(id);
  }

  void clear() {
    memberId = null;
    notifyListeners();
  }

  static Future<int?> loadLastMemberId() async {
    try {
      return await SharedPreferencesAsync().getInt(_lastIdKey);
    } catch (_) {
      return null; // 저장소를 쓸 수 없어도 화면은 동작해야 합니다.
    }
  }

  static Future<void> _saveLast(int id) async {
    try {
      await SharedPreferencesAsync().setInt(_lastIdKey, id);
    } catch (_) {}
  }
}
