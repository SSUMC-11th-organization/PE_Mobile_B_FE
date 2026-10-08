import 'package:shared_preferences/shared_preferences.dart';

/// 사용자가 선택한 장르를 기기 내부(로컬 저장소)에 저장하고 불러오는 클래스입니다.
/// 최신 버전 권장 방식인 `SharedPreferencesAsync`를 사용합니다.
class GenrePreference {
  GenrePreference({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  // 저장소에 저장할 때 사용할 고유 키(Key) 이름입니다.
  static const _selectedGenreKey = 'selected_genre';

  final SharedPreferencesAsync _preferences;

  /// 저장된 장르를 읽어옵니다. 저장된 값이 없으면 기본값인 '전체'를 반환합니다.
  Future<String> read() async {
    return await _preferences.getString(_selectedGenreKey) ?? '전체';
  }

  /// 사용자가 새로 선택한 장르를 저장합니다.
  Future<void> save(String genre) async {
    await _preferences.setString(_selectedGenreKey, genre);
  }

  /// 저장된 장르 데이터를 삭제합니다.
  Future<void> clear() async {
    await _preferences.remove(_selectedGenreKey);
  }
}
