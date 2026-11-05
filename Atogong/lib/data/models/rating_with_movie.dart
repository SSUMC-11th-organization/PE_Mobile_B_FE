import 'rating_dto.dart';
import 'tmdb_movie_dto.dart';

/// 평점(자체 백엔드) + 그 영화 정보(TMDB)를 한 쌍으로. 평점이 주인이라 movie는 없어도 됨
class RatingWithMovie {
  const RatingWithMovie({required this.rating, this.movie});

  final RatingDto rating;
  final TmdbMovieDto? movie; // TMDB에서 못 찾으면 null → 화면은 placeholder
}
