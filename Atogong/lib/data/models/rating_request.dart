/// v6 평점 score는 1~5 정수. 위젯이 정수 단위로 막아 준 뒤에도 남겨 두는 안전장치
int validateServerScore(double value) {
  if (value < 1 || value > 5 || value != value.roundToDouble()) {
    throw ArgumentError('서버 평점은 1~5 사이 정수여야 합니다.');
  }
  return value.toInt();
}

/// POST /v6/members/{memberId}/ratings 요청 body.
/// movieId는 영화 배열 index가 아니라 TmdbMovieDto.id
class CreateRatingRequest {
  const CreateRatingRequest({
    required this.movieId,
    required this.score,
    this.comment,
  });

  final int movieId;
  final int score;
  final String? comment;

  // comment는 선택 항목이라 비어 있으면 빈 문자열 대신 키 자체를 생략
  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'score': score,
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
  };
}
