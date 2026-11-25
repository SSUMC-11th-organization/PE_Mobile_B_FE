/// 즐겨찾기 한 건. POST /v8/favorites 의 result이자 GET /v8/favorites 배열의 항목.
/// 제목·포스터는 없고 movieId(TMDB id)만 있어서 영화 정보는 TMDB에서 따로 가져와 합침
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
    return FavoriteResponseDto(
      favoriteId: (json['favoriteId'] as num).toInt(),
      movieId: (json['movieId'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final int favoriteId;
  final int movieId;
  final DateTime createdAt;
}
