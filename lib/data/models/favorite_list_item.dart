import 'favorite_response_dto.dart';
import 'tmdb_movie_dto.dart';

// 내 즐겨찾기 카드 한 장 — 즐겨찾기(MovieLog) + 영화 정보(TMDB)
// 사용자별 즐겨찾기와 TMDB 공개 정보를 같은 Map에 섞지 않고 카드 단위로만 결합
class FavoriteListItem {
  const FavoriteListItem({
    required this.favorite,
    this.movie,
    this.errorMessage,
  });

  final FavoriteResponseDto favorite;
  final TmdbMovieDto? movie; // TMDB 조회에 실패하면 null → placeholder + 재조회
  final String? errorMessage;

  bool get hasMovie => movie != null;
}
