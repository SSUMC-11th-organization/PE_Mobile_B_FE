import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'sign_up_view_model.dart' show SubmitStatus;

// 영화 상세 화면 상태 — 영화 정보 + 평점 등록 요청 상태
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._ratingService, this.memberId, this.movie);

  final RatingApiService _ratingService;
  final int? memberId; // 학습용 회원가입 전이면 null
  final TmdbMovieDto movie;
  bool _disposed = false;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage; // 실패 시 화면에 보여줄 문구

  Future<void> createRating({required int score, String? comment}) async {
    if (submitStatus == SubmitStatus.submitting) return; // 제출 중 중복 호출 무시
    final id = memberId;
    if (id == null) {
      submitStatus = SubmitStatus.error;
      submitMessage = '먼저 회원가입을 완료해 주세요.';
      _notify();
      return;
    }
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    _notify();
    try {
      await _ratingService.createRating(
        memberId: id,
        request: CreateRatingRequest(
          movieId: movie.id,
          score: score,
          comment: comment,
        ),
      );
      if (_disposed) return;
      submitStatus = SubmitStatus.success;
    } on DioException catch (e) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      submitMessage = writeErrorMessage(e);
    } on StateError catch (e) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      submitMessage = e.message;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
