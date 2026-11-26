import 'package:flutter/foundation.dart';

import '../core/utils/safe_notify.dart';
import '../data/models/tmdb_genre_dto.dart';
import '../data/services/tmdb_movie_service.dart';

/// 영화 목록 화면의 장르 상태(장르 목록, 선택한 장르)만 관리.
/// 9주차: 5주차의 "Discover 최대 30개 수집"은 PagedMoviesViewModel의 더 보기로 대체되어 영화 목록은 여기서 다루지 않음
class MovieListViewModel extends ChangeNotifier with SafeNotify {
  MovieListViewModel(this._service);
  final TmdbMovieService _service;

  List<TmdbGenreDto> genres = const [];
  int? selectedGenreId; // null이면 "전체" (with_genres 안 보냄)

  /// 장르 Chip에 쓸 목록. 실패하면 "전체" Chip만 보이고, 영화 목록의 다시 시도에서 함께 재요청
  Future<void> loadGenres() async {
    if (genres.isNotEmpty) return;
    try {
      final result = await _service.fetchGenres();
      if (isDisposed) return;
      genres = result;
      notifyIfAlive();
    } catch (_) {
      // 장르 목록이 없어도 전체 영화 목록은 볼 수 있으므로 화면을 막지 않음
    }
  }

  void selectGenre(int? genreId) {
    if (selectedGenreId == genreId) return;
    selectedGenreId = genreId;
    notifyIfAlive();
  }
}
