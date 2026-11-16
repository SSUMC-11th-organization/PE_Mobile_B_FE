import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_dto.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';
import 'session_ratings.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty }

/// 내가 등록한 평점 화면.
/// 8주차: memberId로 서버 목록을 조회하던 것을 이번 세션에서 등록한 평점(SessionRatings)으로 바꾸고,
/// 수정·삭제는 v7 토큰 기반 API로 요청. 평점의 movieId(TMDB id)로 제목·포스터를 연결하는 부분은 그대로
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(
    this._service,
    this._movieService,
    this._auth,
    this._sessionRatings,
  );
  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final AuthViewModel _auth;
  final SessionRatings _sessionRatings;
  final Map<int, TmdbMovieDto?> _movieCache = {}; // 같은 movieId는 한 번만 조회
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();

    final rawRatings = _sessionRatings.ratings;
    final entries = <RatingWithMovie>[];
    var missingMovies = 0;
    // 영화 조회 실패가 평점 목록을 지우지 않음. TMDB에 없는 id는 화면에서 placeholder로 표시
    for (final rating in rawRatings) {
      if (_disposed || version != _requestVersion) return;
      if (!_movieCache.containsKey(rating.movieId)) {
        try {
          _movieCache[rating.movieId] = await _movieService.findMovieById(
            rating.movieId,
          );
        } on DioException {
          // 일시적 네트워크 실패는 캐시하지 않음. 다음 로딩에서 재시도
        }
      }
      final movie = _movieCache[rating.movieId];
      if (movie == null) missingMovies++;
      entries.add(RatingWithMovie(rating: rating, movie: movie));
    }
    if (_disposed || version != _requestVersion) return;
    ratings = entries;
    status = entries.isEmpty
        ? MyRatingsLoadStatus.empty
        : MyRatingsLoadStatus.success;
    if (missingMovies > 0) {
      message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
    }
    notifyListeners();
  }

  // ---------- 수정·삭제 (v7) ----------
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final sessionVersion = _auth.sessionVersion;
    final RatingDto updated;
    try {
      updated = await _service.updateRating(
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
    } on DioException catch (error) {
      await _handleWriteError(error, ratingId, sessionVersion);
      rethrow; // 쓰기 실패일 때만 Dialog가 실패로 처리
    }
    // 로그아웃·회원 전환 뒤 늦게 도착한 응답은 반영하지 않음
    if (sessionVersion != _auth.sessionVersion) return;
    _sessionRatings.replace(updated); // 수정 result의 Rating 객체로 카드 갱신
    if (_disposed) return;
    await load();
  }

  Future<void> deleteRating(int ratingId) async {
    final sessionVersion = _auth.sessionVersion;
    try {
      await _service.deleteRating(ratingId);
    } on DioException catch (error) {
      await _handleWriteError(error, ratingId, sessionVersion);
      rethrow;
    }
    if (sessionVersion != _auth.sessionVersion) return;
    _sessionRatings.remove(ratingId);
    if (_disposed) return;
    await load();
  }

  /// 문구는 서버 message, 다음 행동은 code로 결정.
  /// 401(AUTH401_2/3/4): 세션 정리 → Router가 /login으로 이동
  /// 404(RATING404_1): 서버에 이미 없는 평점이라 목록에서도 제거
  /// 403(RATING403_1)·400: 안내만 하고 로그인 상태 유지
  Future<void> _handleWriteError(
    DioException error,
    int ratingId,
    int sessionVersion,
  ) async {
    if (_disposed || sessionVersion != _auth.sessionVersion) return;
    final code = apiErrorCode(error);
    if (isSessionExpiredCode(code)) {
      await _auth.expireSession();
      return;
    }
    message = writeErrorMessage(error);
    if (code == 'RATING404_1') {
      _sessionRatings.remove(ratingId);
      await load();
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
