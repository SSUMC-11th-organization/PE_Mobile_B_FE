import 'json_parsers.dart';

// TMDB 장르 { id, name } — /genre/movie/list 응답의 genres[] 항목
class TmdbGenreDto {
  const TmdbGenreDto({required this.id, required this.name});

  final int id;
  final String name;

  factory TmdbGenreDto.fromJson(Map<String, dynamic> json) {
    return TmdbGenreDto(
      id: parseInt(json['id']),
      name: parseString(json['name']),
    );
  }
}
