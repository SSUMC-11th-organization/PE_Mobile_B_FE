import 'package:shared_preferences/shared_preferences.dart';

/// Challenge: "이메일 저장" 체크박스
/// 비민감 정보인 이메일만 SharedPreferences에 저장합니다. 비밀번호·토큰은 절대 저장하지 않습니다.
class SavedEmailStorage {
  SavedEmailStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'movielog.saved_email';
  final SharedPreferencesAsync _preferences;

  Future<String?> read() => _preferences.getString(_key);

  Future<void> save(String email) => _preferences.setString(_key, email.trim());

  Future<void> clear() => _preferences.remove(_key);
}
