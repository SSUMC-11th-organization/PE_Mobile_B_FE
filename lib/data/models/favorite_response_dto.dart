// POST /v8/favorites 성공 응답의 result, GET /v8/favorites 목록의 원소
// { favoriteId, movieId, createdAt } — 계약과 다르면 FormatException
class FavoriteResponseDto {
  const FavoriteResponseDto({
    required this.favoriteId,
    required this.movieId,
    required this.createdAt,
  });

  factory FavoriteResponseDto.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('FavoriteResponseDto must be a JSON object.');
    }
    final favoriteId = json['favoriteId'];
    final movieId = json['movieId'];
    final createdAt = json['createdAt'];
    if (favoriteId is! num || movieId is! num || createdAt is! String) {
      throw const FormatException('FavoriteResponseDto 형식이 올바르지 않습니다.');
    }
    return FavoriteResponseDto(
      favoriteId: favoriteId.toInt(),
      movieId: movieId.toInt(),
      createdAt: DateTime.parse(createdAt), // ISO 형식이 아니면 FormatException
    );
  }

  final int favoriteId;
  final int movieId; // TMDB 영화 ID
  final DateTime createdAt;
}
