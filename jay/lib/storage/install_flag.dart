import 'package:jay/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 11. (심화) iOS 재설치와 최초 설치 flag
///
/// 일부 iOS 환경에서는 앱을 지워도 Keychain 값이 남습니다.
/// SharedPreferences는 앱 삭제 시 함께 지워지므로, flag가 없으면 "새로 설치된 앱"으로 보고
/// 이전 설치에서 남은 secure storage 값을 정리합니다.
/// 보안 수단도, 완벽한 재설치 감지기도 아닙니다(백업/복원 상황에 따라 달라질 수 있음).
class InstallFlag {
  InstallFlag(this._tokenStorage, {SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'movielog.install_initialized';

  final TokenStorage _tokenStorage;
  final SharedPreferencesAsync _preferences;
  bool _checked = false;

  /// restoreSession()이 토큰을 읽기 전에 호출합니다. 한 번 성공하면 다시 확인하지 않습니다.
  Future<void> ensureInitialized() async {
    if (_checked) return;
    final initialized = await _preferences.getBool(_key) ?? false;
    if (!initialized) {
      // 1~2. flag가 없으면 기존 secure storage 값을 모두 삭제
      await _tokenStorage.clearAll();
      // 3. 삭제가 성공한 뒤에만 flag를 기록 (실패하면 다음 실행에서 다시 시도)
      await _preferences.setBool(_key, true);
    }
    _checked = true;
  }
}
