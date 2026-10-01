import 'package:shared_preferences/shared_preferences.dart';

// 마지막 선택 장르 저장 — shared_preferences는 민감하지 않은 설정값 전용
class GenrePreference {
  GenrePreference({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _selectedGenreKey = 'selected_genre';
  static const allGenresLabel = '전체';

  final SharedPreferencesAsync _preferences;

  Future<String> read() async {
    return await _preferences.getString(_selectedGenreKey) ?? allGenresLabel;
  }

  Future<void> save(String genre) async {
    await _preferences.setString(_selectedGenreKey, genre);
  }
}
