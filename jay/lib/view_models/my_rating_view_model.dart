import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jay/data/models/rating_with_movie.dart';
import 'package:jay/data/models/tmdb_movie_dto.dart';
import 'package:jay/data/services/rating_api_service.dart';
import 'package:jay/data/services/tmdb_movie_service.dart';

const int sampleMemberId = 1;

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);
  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final int memberId;
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;
  String? refreshWarning;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    refreshWarning = null; // 이전 쓰기의 재조회 경고가 일반 조회 실패에 남지 않게 합니다.
    notifyListeners();
    try {
      final rawRatings = await _service.fetchMyRatings(memberId);
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
    }
    if (!_disposed && version == _requestVersion) notifyListeners();
  }

  Future<void> _refreshAfterWrite() async {
    await load();
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
      message = writeErrorMessage(error);
      notifyListeners();
      if (shouldRefreshAfterRatingError(error)) await load();
      rethrow;
    }
    await _refreshAfterWrite();
  }

  Future<void> deleteRating(int ratingId) async {
    try {
      await _service.deleteRating(memberId: memberId, ratingId: ratingId);
    } on DioException catch (error) {
      message = writeErrorMessage(error);
      notifyListeners();
      if (shouldRefreshAfterRatingError(error)) await load();
      rethrow;
    }
    await _refreshAfterWrite();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
