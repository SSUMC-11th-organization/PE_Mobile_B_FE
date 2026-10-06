import 'package:shared_preferences/shared_preferences.dart';

class GenrePreference {
  GenrePreference({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _selectedGenresKey = 'selected_genres';
  final SharedPreferencesAsync _preferences;

  Future<Set<String>> read() async {
    final saved = await _preferences.getStringList(_selectedGenresKey);
    return saved?.toSet() ?? <String>{};
  }

  Future<void> save(Set<String> genres) =>
      _preferences.setStringList(_selectedGenresKey, genres.toList());
}
