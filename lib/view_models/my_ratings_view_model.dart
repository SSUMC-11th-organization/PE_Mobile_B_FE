import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_dto.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/api_response.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';
import 'session_ratings_store.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

// 평점 기록 화면(/my/ratings)
// - 이번 세션에 등록한 평점(SessionRatingsStore) + 학습용 memberId를 알 때만 공개 조회 결과를 합쳐 표시
// - ratingId 기준 중복 제거 (같은 id면 서버 공개 조회 값을 우선)
// - 한계: memberId 없이 토큰만으로 "내 평점 전체"를 조회하는 API가 없어, 앱 재시작 뒤 이번 세션 평점은 복원되지 않음
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(
    this._service,
    this._movieService,
    this._store,
    this._auth,
    this.memberId,
  );

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final SessionRatingsStore _store;
  final AuthViewModel _auth; // sessionVersion 확인용
  final int? memberId; // 학습용 memberId — null이면 공개 조회 없이 이번 세션 평점만

  // movieId → TMDB 영화. 이번 세션 등록 시의 영화 정보로 먼저 채우고, 없으면 TMDB 상세로 보충
  // null 값 = TMDB에 없는 영화(404) → 평점은 지우지 않고 '영화 #id'로 표시
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;
  bool _isWriting = false; // 수정/삭제 요청 진행 중

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message; // 목록 위 안내 (공개 조회 실패, 영화 정보 일부 없음 등)
  // 수정/삭제는 성공했지만 이어진 목록 재조회가 실패한 경우의 안내
  String? refreshWarning;

  Future<void> load() async {
    final version = ++_requestVersion;
    final sessionVersion = _auth.sessionVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    _notify();

    final notices = <String>[];
    var remote = const <RatingDto>[];
    var remoteFailed = false;
    final id = memberId;
    if (id != null) {
      try {
        remote = await _service.fetchMemberRatings(id); // 공개용 Dio
      } on DioException catch (e) {
        remoteFailed = true;
        final info = describeRatingError(e);
        if (!info.isSilent) notices.add('공개 조회 실패: ${info.message}');
      } on InvalidApiResponseException {
        remoteFailed = true;
        notices.add('공개 조회 응답을 확인하지 못했습니다.');
      }
    }
    if (!_isCurrent(version, sessionVersion)) return;

    // ratingId 기준 병합 — 서버 공개 조회 값을 먼저, 이번 세션에만 있는 평점을 뒤에
    final byId = <int, RatingDto>{};
    for (final r in remote) {
      byId[r.ratingId] = r;
    }
    for (final r in _store.ratings) {
      byId.putIfAbsent(r.ratingId, () => r);
    }

    // 영화 정보: Map<int, TmdbMovieDto>에서 찾고, 없으면 TMDB 상세 조회(TMDB Dio)
    _store.movies.forEach((movieId, movie) {
      _movieCache.putIfAbsent(movieId, () => movie);
    });
    var missing = 0;
    final entries = <RatingWithMovie>[];
    for (final rating in byId.values) {
      if (!_movieCache.containsKey(rating.movieId)) {
        try {
          _movieCache[rating.movieId] =
              await _movieService.findMovieById(rating.movieId);
        } on DioException {
          // 일시 실패는 캐시하지 않음 → 다음 조회에서 다시 시도
        }
        if (!_isCurrent(version, sessionVersion)) return;
      }
      final movie = _movieCache[rating.movieId];
      if (movie == null) missing++;
      entries.add(RatingWithMovie(rating: rating, movie: movie));
    }
    entries.sort((a, b) => b.rating.createdAt.compareTo(a.rating.createdAt));

    if (missing > 0) {
      notices.add('일부 영화 정보를 찾지 못해 "영화 #번호"로 표시합니다.');
    }
    ratings = entries;
    refreshWarning = null;
    message = notices.isEmpty ? null : notices.join('\n');
    if (entries.isEmpty && remoteFailed) {
      status = MyRatingsLoadStatus.error;
    } else {
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
    }
    _notify();
  }

  // PATCH는 전체 교체 — Dialog가 기존 score/comment를 채워 열고 두 값을 항상 함께 보냄
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) =>
      _write(ratingId, () async {
        final updated = await _service.updateRating(
          ratingId: ratingId,
          score: score,
          comment: comment,
        );
        return () => _store.replaceIfPresent(updated);
      });

  // 마지막 항목을 지우면 재조회 결과가 빈 목록 → empty 상태로 표시됨
  Future<void> deleteRating(int ratingId) => _write(ratingId, () async {
        await _service.deleteRating(ratingId);
        return () => _store.remove(ratingId);
      });

  // 수정/삭제 공통 처리
  // - 실패: StateError(문구)를 던져 Dialog가 표시. 세션 만료·세션 변경은 RatingActionCancelled(문구 없음)
  // - 성공: 세션이 그대로일 때만 로컬 목록에 반영하고 목록 재조회 (재조회 실패는 던지지 않음)
  Future<void> _write(
    int ratingId,
    Future<void Function()> Function() call,
  ) async {
    if (_isWriting) {
      // 무시하고 조용히 끝내면 호출한 Dialog가 성공으로 오해하므로 실패로 알림
      throw StateError('이전 요청을 처리하고 있습니다. 잠시 후 다시 시도해 주세요.');
    }
    _isWriting = true;
    final sessionVersion = _auth.sessionVersion;
    final void Function() apply;
    try {
      apply = await call();
    } on DioException catch (e) {
      final info = describeRatingError(e);
      if (info.isSilent || _auth.sessionVersion != sessionVersion) {
        throw const RatingActionCancelled();
      }
      if (info.type == RatingErrorType.notFound) {
        _store.remove(ratingId); // 서버에 없는 평점은 이번 세션 목록에서도 제거
      }
      if (info.refreshList && !_disposed) await load();
      throw StateError(info.message);
    } on InvalidApiResponseException {
      throw StateError('처리 결과를 확인하지 못했습니다. 목록을 새로 불러와 확인해 주세요.');
    } finally {
      _isWriting = false;
    }
    if (_auth.sessionVersion != sessionVersion) {
      throw const RatingActionCancelled(); // 늦게 온 응답 → 반영하지 않음
    }
    apply();
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
    _notify();
  }

  bool _isCurrent(int version, int sessionVersion) =>
      !_disposed &&
      version == _requestVersion &&
      sessionVersion == _auth.sessionVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
