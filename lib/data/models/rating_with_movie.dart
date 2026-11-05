import 'rating_dto.dart';
import 'tmdb_movie_dto.dart';

// 평점 한 건 + 해당 TMDB 영화 정보 (화면 표시용 묶음)
class RatingWithMovie {
  const RatingWithMovie({required this.rating, this.movie});

  final RatingDto rating;
  final TmdbMovieDto? movie; // TMDB에서 못 찾으면 null
}
