import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_dto.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// 이번 로그인 세션에서 등록한 평점을 메모리에 보관하는 앱 전역 저장소.
/// v7에는 토큰으로 "내 평점 전체"를 조회하는 API가 없어, 재시작 후 복원은 하지 않습니다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this._auth) {
    _seenSession = _auth.sessionVersion;
    _auth.addListener(_onAuthChanged);
  }

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final AuthViewModel _auth;

  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _seenSession = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  // idle은 화면에서 로딩으로 그려지므로 빈 상태로 시작합니다.
  MyRatingsLoadStatus status = MyRatingsLoadStatus.empty;
  String? message;

  // ---- Challenge: 다중 선택 삭제 ----
  bool isSelecting = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  void startSelecting() {
    isSelecting = true;
    selectedRatingIds.clear();
    notifyListeners();
  }

  void cancelSelecting() {
    isSelecting = false;
    selectedRatingIds.clear();
    notifyListeners();
  }

  void toggleSelected(int ratingId) {
    if (!selectedRatingIds.remove(ratingId)) selectedRatingIds.add(ratingId);
    notifyListeners();
  }

  /// 세션이 바뀌면(로그인·로그아웃·만료) 이전 사용자의 목록을 비웁니다.
  /// TMDB 영화 캐시는 공개 데이터이므로 유지합니다.
  void _onAuthChanged() {
    if (_auth.sessionVersion == _seenSession) return;
    _seenSession = _auth.sessionVersion;
    ratings = const [];
    status = MyRatingsLoadStatus.empty;
    message = null;
    isSelecting = false;
    selectedRatingIds.clear();
    notifyListeners();
  }

  /// 등록 응답의 Rating을 목록 맨 앞에 추가합니다.
  void addCreated(RatingDto rating, TmdbMovieDto movie) {
    _movieCache[rating.movieId] = movie;
    ratings = [RatingWithMovie(rating: rating, movie: movie), ...ratings];
    status = MyRatingsLoadStatus.success;
    notifyListeners();
  }

  void _replace(RatingDto updated) {
    ratings = [
      for (final e in ratings)
        e.rating.ratingId == updated.ratingId
            ? RatingWithMovie(rating: updated, movie: e.movie)
            : e,
    ];
    notifyListeners();
  }

  void _removeLocal(int ratingId) {
    ratings = ratings.where((e) => e.rating.ratingId != ratingId).toList();
    selectedRatingIds.remove(ratingId);
    status = ratings.isEmpty
        ? MyRatingsLoadStatus.empty
        : MyRatingsLoadStatus.success;
    notifyListeners();
  }

  /// 제목·포스터를 못 찾아 placeholder인 항목만 TMDB에서 다시 조회합니다.
  /// 평점 자체는 지우지 않습니다.
  Future<void> load() async {
    final seen = _seenSession;
    var missing = 0;
    final next = <RatingWithMovie>[];
    for (final e in ratings) {
      var movie = e.movie ?? _movieCache[e.rating.movieId];
      if (movie == null) {
        try {
          movie = await _movieService.findMovieById(e.rating.movieId);
          _movieCache[e.rating.movieId] = movie;
        } catch (_) {
          // 실패해도 평점은 유지하고 placeholder로 표시합니다.
        }
      }
      if (movie == null) missing++;
      next.add(RatingWithMovie(rating: e.rating, movie: movie));
    }
    if (_disposed || seen != _seenSession) return; // 세션이 바뀌었으면 무시
    ratings = next;
    message =
        missing > 0 ? '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.' : null;
    notifyListeners();
  }

  /// 쓰기 실패: 만료면 세션 정리, 404면 로컬에서 제거, 그 외(403·409 등)는 안내만 합니다.
  Future<Never> _failWrite(
    DioException error,
    int version, {
    int? ratingId,
  }) async {
    final code = apiErrorCode(error);
    if (isSessionExpiredCode(code)) {
      if (version == _auth.sessionVersion) await _auth.expireSession();
    } else if (code == 'RATING404_1' && ratingId != null) {
      _removeLocal(ratingId);
    }
    throw StateError(ratingErrorMessage(error)); // RatingDialog가 그대로 표시
  }

  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final version = _auth.sessionVersion;
    try {
      final updated = await _service.updateRating(
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
      if (_disposed || version != _auth.sessionVersion) return;
      _replace(updated);
    } on DioException catch (error) {
      await _failWrite(error, version, ratingId: ratingId);
    }
  }

  Future<void> deleteRating(int ratingId) async {
    final version = _auth.sessionVersion;
    try {
      await _service.deleteRating(ratingId);
      if (_disposed || version != _auth.sessionVersion) return;
      _removeLocal(ratingId);
    } on DioException catch (error) {
      await _failWrite(error, version, ratingId: ratingId);
    }
  }

  Future<void> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return;
    final version = _auth.sessionVersion;
    isDeletingSelected = true;
    notifyListeners();
    var failed = 0;
    try {
      // 원본 Set을 순회하며 remove하면 ConcurrentModificationError → 복사본 순회
      for (final ratingId in selectedRatingIds.toList()) {
        if (version != _auth.sessionVersion) break;
        try {
          await _service.deleteRating(ratingId);
          _removeLocal(ratingId);
        } on DioException catch (error) {
          final code = apiErrorCode(error);
          if (isSessionExpiredCode(code)) {
            await _auth.expireSession();
            return;
          }
          if (code == 'RATING404_1') {
            _removeLocal(ratingId); // 서버에 이미 없는 항목
          } else {
            failed++; // 실패한 항목은 선택 상태를 유지합니다.
          }
        }
      }
    } finally {
      isDeletingSelected = false;
      if (!_disposed) notifyListeners();
    }
    if (_disposed) return;
    if (failed == 0) {
      isSelecting = false;
    } else {
      message = '$failed개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
