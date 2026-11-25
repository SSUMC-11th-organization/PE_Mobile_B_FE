import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jay/core/network/api_error.dart';
import 'package:jay/data/models/rating_dto.dart';
import 'package:jay/data/models/rating_with_movie.dart';
import 'package:jay/data/models/tmdb_movie_dto.dart';
import 'package:jay/data/services/rating_api_service.dart';
import 'package:jay/data/services/tmdb_movie_service.dart';
import 'package:jay/view_models/auth_view_model.dart';
import 'package:jay/view_models/session_rating_store.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// "내가 등록한 평점"
///
/// - memberId를 알 때(이 앱에서 방금 가입한 계정으로 로그인): 공개 GET /v8/members/{memberId}/ratings
/// - memberId를 모를 때: v8 로그인·내 정보 응답에 memberId가 없고 토큰 기반 목록 GET도 없으므로
///   현재 세션에서 등록한 평점(SessionRatingStore)만 보여줍니다. JWT claim을 추정하지 않습니다.
/// - 수정·삭제는 memberId 없이 v8 보호 API(Authorization 헤더)로 보냅니다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(
    this._service,
    this._movieService,
    this._auth,
    this._store,
    this.memberId,
  );

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final AuthViewModel _auth;
  final SessionRatingStore _store;
  final int? memberId;
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;
  String? refreshWarning;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  /// memberId 없이 세션 평점만 보여주는 중인지 (화면 안내 문구용)
  bool get sessionOnly => memberId == null;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    refreshWarning = null; // 이전 쓰기의 재조회 경고가 일반 조회 실패에 남지 않게 합니다.
    _notify();
    try {
      final id = memberId;
      final rawRatings = id == null
          ? _store.ratings
          : await _service.fetchMyRatings(id);
      if (_disposed || version != _requestVersion) return;
      final entries = <RatingWithMovie>[];
      var missingMovies = 0;

      for (final rating in rawRatings) {
        if (_disposed || version != _requestVersion) return;
        if (!_movieCache.containsKey(rating.movieId)) {
          try {
            _movieCache[rating.movieId] = await _movieService.findMovieById(
              rating.movieId,
            );
          } on DioException {
            log('일시적 네트워크 실패는 캐시하지 않습니다. 다음 로딩에서 재시도합니다');
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
    } catch (_) {
      if (_disposed || version != _requestVersion) return;
      status = MyRatingsLoadStatus.error;
      message = '평점 목록 응답을 확인하지 못했습니다.';
    }
    if (!_disposed && version == _requestVersion) notifyListeners();
  }

  Future<void> _refreshAfterWrite() async {
    await load();
    if (status == MyRatingsLoadStatus.error) {
      refreshWarning = '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.';
      _notify();
    } else {
      refreshWarning = null;
    }
  }

  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final session = _auth.sessionVersion;
    final RatingDto updated;
    try {
      updated = await _service.updateRating(
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
    } on DioException catch (error) {
      await _handleWriteError(error, session);
      rethrow;
    }
    if (session != _auth.sessionVersion) return;
    // 세션 카드에 있던 평점이면 수정 result로 함께 갱신합니다.
    if (_store.ratingForMovie(updated.movieId)?.ratingId == updated.ratingId) {
      _store.put(updated, sessionVersion: session);
    }
    await _refreshAfterWrite();
  }

  Future<void> deleteRating(int ratingId) async {
    final session = _auth.sessionVersion;
    try {
      await _service.deleteRating(ratingId);
    } on DioException catch (error) {
      await _handleWriteError(error, session);
      rethrow;
    }
    if (session != _auth.sessionVersion) return;
    _store.removeByRatingId(ratingId, sessionVersion: session);
    await _refreshAfterWrite();
  }

  Future<void> _handleWriteError(DioException error, int session) async {
    if (_disposed || session != _auth.sessionVersion) return;
    if (isSessionExpiredCode(apiErrorCode(error))) {
      // 401만 세션을 정리합니다. 403·409는 안내만 하고 로그인 상태를 유지합니다.
      await _auth.expireSession(version: session);
      return;
    }
    message = writeErrorMessage(error);
    _notify();
    if (shouldRefreshAfterRatingError(error)) await load();
  }

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
