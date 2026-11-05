class MemberRatingDto {
  final int ratingId;
  final int movieId;
  final int score;
  final String comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MemberRatingDto({
    required this.ratingId,
    required this.movieId,
    required this.score,
    required this.comment,
    this.createdAt,
    this.updatedAt,
  });

  factory MemberRatingDto.fromJson(Map<String, dynamic> json) {
    return MemberRatingDto(
      ratingId: json['ratingId'] as int? ?? 0,
      movieId: json['movieId'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
      comment: json['comment'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}
