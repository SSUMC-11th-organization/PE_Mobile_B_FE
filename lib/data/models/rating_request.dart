// 서버 평점은 1~5 정수만 허용 — 별점 위젯의 double 값을 서버용 int로 변환
int validateServerScore(double score) {
  if (score < 1 || score > 5 || score != score.roundToDouble()) {
    throw ArgumentError.value(score, 'score', '평점은 1~5 사이의 정수여야 합니다.');
  }
  return score.toInt();
}

// POST /v6/members/{memberId}/ratings 요청 본문
class CreateRatingRequest {
  const CreateRatingRequest({
    required this.movieId,
    required this.score,
    this.comment,
  });

  final int movieId; // TMDB 영화 id
  final int score; // 1~5 정수
  final String? comment; // 선택, 500자 이하

  // comment는 trim 후 비어 있으면 아예 보내지 않음
  Map<String, dynamic> toJson() {
    final trimmed = comment?.trim();
    return {
      'movieId': movieId,
      'score': score,
      if (trimmed != null && trimmed.isNotEmpty) 'comment': trimmed,
    };
  }
}
