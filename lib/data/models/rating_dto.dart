// 워크북 평점 응답 한 건 — GET /v6/members/{memberId}/ratings 의 배열 원소
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

  factory RatingDto.fromJson(Map<String, dynamic> json) => RatingDto(
        ratingId: (json['ratingId'] as num).toInt(),
        movieId: (json['movieId'] as num).toInt(),
        score: (json['score'] as num).toInt(),
        comment: json['comment'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
