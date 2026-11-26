class FavoriteCheckDto {
  const FavoriteCheckDto({required this.movieId, required this.isFavorite});

  /// 응답에는 movieId가 없으므로 요청에 사용한 값을 받습니다.
  factory FavoriteCheckDto.fromJson(Object? json, {required int movieId}) {
    if (json is! Map<String, Object?> || json['isFavorite'] is! bool) {
      throw const FormatException('isFavorite must be a boolean.');
    }
    return FavoriteCheckDto(
      movieId: movieId,
      isFavorite: json['isFavorite'] as bool,
    );
  }

  final int movieId;
  final bool isFavorite;
}
