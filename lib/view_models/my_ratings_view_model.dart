import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';

const int sampleMemberId = 1; // 인증된 '내 계정'이 아닌 학습용 데이터

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

// 샘플 회원의 평점 목록 + 각 평점의 TMDB 영화 정보를 불러오는 ViewModel
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final int memberId;
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;
  bool _isWriting = false; // 수정/삭제 요청 진행 중

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;
  // 수정/삭제는 성공했지만 이어진 목록 재조회가 실패한 경우의 안내
  String? refreshWarning;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    if (!_disposed) notifyListeners();
    try {
      final raw = await _service.fetchMyRatings(memberId);
      if (_disposed || version != _requestVersion) return;
      final entries = <RatingWithMovie>[];
      var missing = 0;
      for (final rating in raw) {
        if (_disposed || version != _requestVersion) return;
        if (!_movieCache.containsKey(rating.movieId)) {
          try {
            _movieCache[rating.movieId] =
                await _movieService.findMovieById(rating.movieId);
          } on DioException {
            // 일시 실패는 캐시하지 않음
          }
        }
        final movie = _movieCache[rating.movieId];
        if (movie == null) missing++;
        entries.add(RatingWithMovie(rating: rating, movie: movie));
      }
      if (_disposed || version != _requestVersion) return;
      ratings = entries;
      refreshWarning = null; // 조회에 성공했으니 재조회 실패 안내는 해제
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      if (missing > 0) {
        message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
      }
    } on DioException catch (e) {
      if (_disposed || version != _requestVersion) return;
      status = MyRatingsLoadStatus.error;
      message = writeMyRatingsErrorMessage(e);
    }
    if (!_disposed && version == _requestVersion) notifyListeners();
  }

  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) =>
      _write(
        () => _service.updateRating(
          memberId: memberId,
          ratingId: ratingId,
          score: score,
          comment: comment,
        ),
      );

  // 마지막 항목을 지우면 재조회 결과가 빈 배열 → 기존 empty 상태로 표시됨
  Future<void> deleteRating(int ratingId) => _write(
        () => _service.deleteRating(memberId: memberId, ratingId: ratingId),
      );

  // 수정/삭제 공통 처리 — 실패는 다시 던져 Dialog가 실패로 처리, 성공 후 목록 재조회 실패는 던지지 않음
  Future<void> _write(Future<void> Function() call) async {
    if (_isWriting) {
      // 무시하고 조용히 끝내면 호출한 Dialog가 성공으로 오해하므로 실패로 알림
      throw StateError('이전 요청을 처리하고 있습니다. 잠시 후 다시 시도해 주세요.');
    }
    _isWriting = true;
    try {
      await call();
    } on DioException catch (e) {
      if (!_disposed) {
        message = writeErrorMessage(e);
        notifyListeners();
        // 권한 없음/이미 삭제됨 → 화면 목록이 서버와 다를 수 있어 다시 조회
        if (shouldRefreshAfterRatingError(e)) await load();
      }
      rethrow;
    } finally {
      _isWriting = false;
    }
    await _refreshAfterWrite();
  }

  // 쓰기 성공 후 목록 재조회 — 실패해도 예외 없이 안내 문구만 남김 (쓰기는 재전송하지 않음)
  Future<void> _refreshAfterWrite() async {
    if (_disposed) return;
    await load();
    if (_disposed) return;
    refreshWarning = status == MyRatingsLoadStatus.error
        ? '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.'
        : null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
