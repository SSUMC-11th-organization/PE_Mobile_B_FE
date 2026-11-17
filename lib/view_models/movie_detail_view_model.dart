import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'auth_view_model.dart';
import 'my_ratings_view_model.dart';
import 'sign_up_view_model.dart' show SubmitStatus;

export 'sign_up_view_model.dart' show SubmitStatus;

class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(
    this._ratingService,
    this._auth,
    this._myRatings,
    this.movie,
  );

  final RatingApiService _ratingService;
  final AuthViewModel _auth;
  final MyRatingsViewModel _myRatings;
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;
  bool _disposed = false;

  Future<void> createRating({required int score, String? comment}) async {
    if (submitStatus == SubmitStatus.submitting) return;
    final version = _auth.sessionVersion; // 요청 시점의 세션 번호표
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();
    try {
      final rating = await _ratingService.createRating(
        CreateRatingRequest(
          movieId: movie.id, // TmdbMovieDto.id (memberId는 보내지 않음)
          score: score,
          comment: comment,
        ),
      );
      if (_disposed || version != _auth.sessionVersion) return;
      _myRatings.addCreated(rating, movie); // 응답의 Rating으로 목록 갱신
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_disposed || version != _auth.sessionVersion) return;
      if (isSessionExpiredCode(apiErrorCode(error))) {
        await _auth.expireSession(); // Router가 /login으로 이동
      }
      submitStatus = SubmitStatus.error; // 403·409 등은 안내만, 로그아웃하지 않음
      submitMessage = ratingErrorMessage(error);
    } on StateError catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      submitMessage = error.message;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
