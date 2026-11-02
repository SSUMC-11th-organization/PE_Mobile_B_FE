import 'json_parsers.dart';

// TMDB 영화 목록 응답(results[])의 영화 한 편 — /movie/popular, /discover/movie 공통
class TmdbMovieDto {
  const TmdbMovieDto({
    required this.id,
    required this.title,
    required this.originalTitle,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.voteAverage,
    required this.voteCount,
    required this.popularity,
    required this.genreIds,
    required this.adult,
  });

  final int id;
  final String title;
  final String originalTitle;
  final String overview;
  final String? posterPath; // 예: /abc.jpg — 포스터 없는 영화는 null
  final String? backdropPath;
  final String releaseDate; // 예: 2024-05-01 — 미개봉 등은 빈 문자열
  final double voteAverage; // 0~10
  final int voteCount;
  final double popularity;
  final List<int> genreIds;
  final bool adult;

  factory TmdbMovieDto.fromJson(Map<String, dynamic> json) {
    return TmdbMovieDto(
      id: parseInt(json['id']),
      title: parseString(json['title']),
      originalTitle: parseString(json['original_title']),
      overview: parseString(json['overview']),
      posterPath: parseNullableString(json['poster_path']),
      backdropPath: parseNullableString(json['backdrop_path']),
      releaseDate: parseString(json['release_date']),
      voteAverage: parseDouble(json['vote_average']),
      voteCount: parseInt(json['vote_count']),
      popularity: parseDouble(json['popularity']),
      genreIds: parseIntList(json['genre_ids']),
      adult: parseBool(json['adult']),
    );
  }

  // release_date의 연도 — 형식이 맞지 않으면 null
  int? get releaseYear {
    if (releaseDate.length < 4) return null;
    return int.tryParse(releaseDate.substring(0, 4));
  }
}
