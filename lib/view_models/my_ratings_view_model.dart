import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';

const int sampleMemberId = 1; // 6주차는 학습용 memberId 1 고정

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(
    this._service,
    this._movieService, [
    this._memberId = sampleMemberId,
  ]);

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  int _memberId;

  int get memberId => _memberId;

  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  /// 저장은 성공했지만 목록 재조회(GET)가 실패했을 때의 안내. 쓰기를 다시 보내지 않습니다.
  String? refreshWarning;

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

  /// 평점 목록 불러오기
  Future<void> load([int? targetMemberId]) async {
    if (targetMemberId != null) {
      _memberId = targetMemberId;
    }
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    refreshWarning = null;
    notifyListeners();

    try {
      final rawRatings = await _service.fetchMyRatings(_memberId);
      if (_disposed || version != _requestVersion) return;

      final entries = <RatingWithMovie>[];
      var missingMovies = 0;

      // 같은 movieId는 캐시를 사용하고, 영화 조회 실패가 평점 목록을 지우지 않습니다.
      for (final rating in rawRatings) {
        if (_disposed || version != _requestVersion) return;
        if (!_movieCache.containsKey(rating.movieId)) {
          try {
            _movieCache[rating.movieId] =
                await _movieService.findMovieById(rating.movieId);
          } on DioException {
            // 일시적 네트워크 실패는 캐시하지 않습니다. 다음 로딩에서 재시도합니다.
          } catch (_) {}
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
    } catch (e) {
      if (_disposed || version != _requestVersion) return;
      status = MyRatingsLoadStatus.error;
      message = '알 수 없는 오류가 발생했습니다: $e';
    }

    if (!_disposed && version == _requestVersion) {
      notifyListeners();
    }
  }

  Future<void> _refreshAfterWrite() async {
    await load(); // GET 실패는 status=error로 기록됩니다.
    if (_disposed) return;
    if (status == MyRatingsLoadStatus.error) {
      refreshWarning = '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.';
      notifyListeners();
    }
  }

  /// 쓰기 실패: 서버 message를 StateError로 감싸 Dialog가 그대로 보여주게 합니다.
  Future<Never> _failWrite(DioException error) async {
    final text = writeErrorMessage(error);
    if (shouldRefreshAfterRatingError(error)) await load();
    throw StateError(text);
  }

  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    try {
      await _service.updateRating(
        memberId: _memberId,
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
    } on DioException catch (error) {
      await _failWrite(error);
    }
    await _refreshAfterWrite(); // GET 실패를 저장 실패로 다시 던지지 않습니다.
  }

  Future<void> deleteRating(int ratingId) async {
    try {
      await _service.deleteRating(memberId: _memberId, ratingId: ratingId);
    } on DioException catch (error) {
      await _failWrite(error);
    }
    await _refreshAfterWrite();
  }

  Future<void> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return;
    isDeletingSelected = true;
    notifyListeners();
    var failed = 0;
    try {
      // 원본 Set을 순회하며 remove하면 ConcurrentModificationError → 복사본 순회
      for (final ratingId in selectedRatingIds.toList()) {
        try {
          await _service.deleteRating(memberId: _memberId, ratingId: ratingId);
          selectedRatingIds.remove(ratingId);
        } on DioException {
          failed++; // 실패한 항목은 선택 상태를 유지합니다.
        }
      }
    } finally {
      isDeletingSelected = false;
      if (!_disposed) notifyListeners();
    }
    if (_disposed) return;
    if (failed == 0) isSelecting = false;
    await _refreshAfterWrite();
    if (failed > 0 && !_disposed) {
      message = '$failed개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
