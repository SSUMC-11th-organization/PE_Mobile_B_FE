import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);
  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final int memberId;
  final Map<int, TmdbMovieDto?> _movieCache = {}; // 같은 movieId는 한 번만 조회
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;
  String? refreshWarning; // 쓰기는 성공했는데 그 뒤 목록 재조회(GET)만 실패했을 때의 안내

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    refreshWarning = null;
    notifyListeners();
    try {
      final rawRatings = await _service.fetchMyRatings(memberId);
      if (_disposed || version != _requestVersion) return;
      final entries = <RatingWithMovie>[];
      var missingMovies = 0;
      // 영화 조회 실패가 평점 목록을 지우지 않음
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
    } on DioException catch (error) {
      if (_disposed || version != _requestVersion) return;
      status = MyRatingsLoadStatus.error;
      message = writeMyRatingsErrorMessage(error);
    }
    if (!_disposed && version == _requestVersion) notifyListeners();
  }

  // ---------- 수정·삭제 (7주차) ----------
  // 쓰기 성공 뒤 목록을 서버 상태와 맞춤. 여기서의 GET 실패는 "저장 실패"가 아니므로 다시 던지지 않음
  Future<void> _refreshAfterWrite() async {
    await load(); // load()는 GET 실패를 status=error로 기록
    if (_disposed) return;
    if (status == MyRatingsLoadStatus.error) {
      refreshWarning = '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.';
      notifyListeners();
    } else {
      refreshWarning = null;
    }
  }

  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    try {
      await _service.updateRating(
        memberId: memberId,
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
    } on DioException catch (error) {
      if (_disposed) rethrow;
      message = writeErrorMessage(error);
      notifyListeners();
      // 403·404는 화면 목록이 서버와 어긋났다는 뜻이라 다시 조회해서 맞춤
      if (shouldRefreshAfterRatingError(error)) await load();
      rethrow; // 쓰기 실패일 때만 Dialog가 실패로 처리
    }
    if (_disposed) return; // 화면을 떠난 뒤 도착한 응답은 반영하지 않음
    await _refreshAfterWrite();
  }

  Future<void> deleteRating(int ratingId) async {
    try {
      await _service.deleteRating(memberId: memberId, ratingId: ratingId);
    } on DioException catch (error) {
      if (_disposed) rethrow;
      message = writeErrorMessage(error);
      notifyListeners();
      if (shouldRefreshAfterRatingError(error)) await load();
      rethrow;
    }
    if (_disposed) return;
    await _refreshAfterWrite();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
