import 'favorite_response_dto.dart';
import 'tmdb_movie_dto.dart';

/// 즐겨찾기(MovieLog) + 영화 정보(TMDB). movie가 null이면 그 카드만 조회 실패입니다.
class FavoriteListItem {
  const FavoriteListItem({required this.favorite, this.movie});

  final FavoriteResponseDto favorite;
  final TmdbMovieDto? movie;
}
