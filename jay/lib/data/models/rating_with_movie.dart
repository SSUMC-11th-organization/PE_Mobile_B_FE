import 'package:jay/data/models/rating_dto.dart';
import 'package:jay/data/models/tmdb_movie_dto.dart';

class RatingWithMovie {
  const RatingWithMovie({required this.rating, this.movie});
  final RatingDto rating;
  final TmdbMovieDto? movie;
}
