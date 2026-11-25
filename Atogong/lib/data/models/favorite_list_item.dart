import 'favorite_response_dto.dart';
import 'tmdb_movie_dto.dart';

/// 내 즐겨찾기 목록의 카드 한 장 = MovieLog 즐겨찾기 + (movieId로 찾은) TMDB 영화 정보.
/// 영화 정보를 못 가져온 카드는 movie가 null이고, 그 카드만 placeholder로 표시
class FavoriteListItem {
  const FavoriteListItem({
    required this.favorite,
    this.movie,
    this.errorMessage,
  });

  final FavoriteResponseDto favorite;
  final TmdbMovieDto? movie;
  final String? errorMessage;

  bool get hasMovie => movie != null;
}
