import 'package:flutter/foundation.dart';

import '../data/models/rating_dto.dart';
import '../data/models/tmdb_movie_dto.dart';

// 이번 로그인 세션 동안 등록 응답(POST /v7/ratings)으로 받은 평점을 메모리에만 보관
//
// 한계: v7 로그인·내 정보 응답에는 memberId가 없어 "토큰 기반 내 평점 전체 목록"을 조회할 API가 없음.
// 그래서 이 목록은 저장하지 않으며, 앱을 다시 시작하면 이전에 남긴 평점은 자동으로 복원되지 않음.
// (학습용 memberId를 알고 있을 때만 공개 조회로 서버 기록을 함께 볼 수 있음)
//
// logout / expireSession / 다른 사용자 로그인 시 main.dart에서 clear()
class SessionRatingsStore extends ChangeNotifier {
  final Map<int, RatingDto> _ratings = {}; // ratingId 기준 — 중복 없음
  final Map<int, TmdbMovieDto> _movies = {}; // movieId → 등록 당시 상세 화면의 영화 정보

  List<RatingDto> get ratings => List.unmodifiable(_ratings.values);
  Map<int, TmdbMovieDto> get movies => Map.unmodifiable(_movies);

  void add(RatingDto rating, {TmdbMovieDto? movie}) {
    _ratings[rating.ratingId] = rating;
    if (movie != null) _movies[movie.id] = movie;
    notifyListeners();
  }

  // 이번 세션에 등록한 평점을 수정했을 때만 교체 (공개 조회로만 본 평점은 추가하지 않음)
  void replaceIfPresent(RatingDto rating) {
    if (!_ratings.containsKey(rating.ratingId)) return;
    _ratings[rating.ratingId] = rating;
    notifyListeners();
  }

  void remove(int ratingId) {
    if (_ratings.remove(ratingId) != null) notifyListeners();
  }

  void clear() {
    if (_ratings.isEmpty && _movies.isEmpty) return;
    _ratings.clear();
    _movies.clear();
    notifyListeners();
  }
}
