/// "지금 도착한 응답이 현재 로그인 세션의 것인지"를 판정.
/// 세션이 바뀔 때마다 generation이 올라가므로, 요청을 보낼 때의 값과 응답이 도착했을 때의 값을 비교
class SessionGuard {
  int _generation = 0;
  String? _accountId;

  int get generation => _generation;
  String? get accountId => _accountId;

  // 검증된 새 세션을 시작할 때만 호출 (AuthSessionBridge 전용).
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
