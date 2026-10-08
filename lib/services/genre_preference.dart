import 'package:shared_preferences/shared_preferences.dart';

// 마지막 선택 장르 저장 — shared_preferences는 민감하지 않은 설정값 전용
// 5주차: TMDB 장르 id(int)로 저장. null(=전체)이면 키를 지움
class GenrePreference {
  GenrePreference({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  // 4주차의 'selected_genre'(장르 이름 문자열)와 값 형식이 달라 새 키 사용
  static const _selectedGenreIdKey = 'selected_genre_id';

  final SharedPreferencesAsync _preferences;

  Future<int?> read() {
    return _preferences.getInt(_selectedGenreIdKey);
  }

  Future<void> save(int? genreId) async {
    if (genreId == null) {
      await _preferences.remove(_selectedGenreIdKey);
    } else {
      await _preferences.setInt(_selectedGenreIdKey, genreId);
    }
  }
}
