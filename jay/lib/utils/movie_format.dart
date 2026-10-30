// TMDB 응답 값을 화면 표시용 문자열로 바꾸는 함수 모음

// release_date('2024-05-01')에서 연도만 꺼낸다. 값이 없으면 null → 연도를 표시하지 않음
String? releaseYear(String? releaseDate) {
  if (releaseDate == null || releaseDate.length < 4) return null;
  return releaseDate.substring(0, 4);
}

// TMDB vote_average는 10점 만점이라 MovieLog의 5점 만점으로 변환한다
double fiveStarRating(double voteAverage) => voteAverage / 2;
