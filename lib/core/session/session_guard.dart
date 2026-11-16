// 지금 도착한 응답이 현재 로그인 세션의 것인지 판정
// - AuthViewModel.sessionVersion이 바뀌면 invalidate()
// - /v8/members/me로 확인한 email을 현재 계정으로 사용 (memberId를 추측하지 않음)
class SessionGuard {
  int _generation = 0;
  String? _accountId;

  int get generation => _generation;
  String? get accountId => _accountId;

  // 인증 호스트가 검증된 새 세션을 시작할 때만 호출 (AuthSessionBridge 전용)
  // 화면이나 ViewModel에서 호출하지 않고, build마다 호출하지도 않음
  int startSession(String accountId) {
    _accountId = accountId;
    return ++_generation; // 같은 계정이라도 토큰이 새로 발급되면 새 세션
  }

  void invalidate() {
    _accountId = null;
    _generation++;
  }

  bool isCurrent(int generation, String accountId) =>
      _generation == generation && _accountId == accountId;
}
