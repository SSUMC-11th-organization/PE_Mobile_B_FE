// MovieLog 평점(Rating) 한 건
// - POST /v7/ratings, PATCH /v7/ratings/{ratingId} 성공 응답의 result
// - GET /v7/members/{memberId}/ratings 목록의 원소
class RatingDto {
  const RatingDto({
    required this.ratingId,
    required this.movieId,
    required this.score,
    required this.comment,
    required this.createdAt,
  });

  final int ratingId;
  final int movieId; // TMDB 영화 id
  final int score;
  final String? comment;
  final DateTime createdAt;

  // 계약과 다르면(필드 누락·타입 불일치·ISO 형식 아님) FormatException
  // → parseCommonResult가 InvalidApiResponseException으로 바꿔 던짐
  factory RatingDto.fromJson(Map<String, dynamic> json) {
    final ratingId = json['ratingId'];
    final movieId = json['movieId'];
    final score = json['score'];
    final comment = json['comment'];
    final createdAt = json['createdAt'];
    if (ratingId is! num ||
        movieId is! num ||
        score is! num ||
        (comment != null && comment is! String) ||
        createdAt is! String) {
      throw const FormatException('Rating 형식이 올바르지 않습니다.');
    }
    return RatingDto(
      ratingId: ratingId.toInt(),
      movieId: movieId.toInt(),
      score: score.toInt(),
      comment: comment as String?,
      createdAt: DateTime.parse(createdAt), // ISO 8601이 아니면 FormatException
    );
  }
}
