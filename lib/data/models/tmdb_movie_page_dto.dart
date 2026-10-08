import 'json_parsers.dart';
import 'tmdb_movie_dto.dart';

// TMDB 페이지 단위 목록 응답 { page, results, total_pages, total_results }
class TmdbMoviePageDto {
  const TmdbMoviePageDto({
    required this.page,
    required this.results,
    required this.totalPages,
    required this.totalResults,
  });

  final int page;
  final List<TmdbMovieDto> results;
  final int totalPages;
  final int totalResults;

  factory TmdbMoviePageDto.fromJson(Map<String, dynamic> json) {
    return TmdbMoviePageDto(
      page: parseInt(json['page'], fallback: 1),
      results: parseObjectList(json['results'], TmdbMovieDto.fromJson),
      totalPages: parseInt(json['total_pages']),
      totalResults: parseInt(json['total_results']),
    );
  }

  bool get hasNextPage => page < totalPages;
}
