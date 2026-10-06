import 'package:shared_preferences/shared_preferences.dart';

class GenrePreference {
  GenrePreference({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _selectedGenreKey = 'selected_genre';
  final SharedPreferencesAsync _preferences;

  Future<String> read() async =>
      await _preferences.getString(_selectedGenreKey) ?? '전체';

  Future<void> save(String genre) =>
      _preferences.setString(_selectedGenreKey, genre);
}
