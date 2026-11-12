import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'submit_status.dart';

/// 영화 상세 화면: 현재 영화 DTO와 평점 "등록" 상태만 관리 (조회·수정·삭제는 MyRatingsViewModel)
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._ratingService, this.memberId, this.movie);
  final RatingApiService _ratingService;
  final int? memberId; // 학습용 현재 회원(LearningMemberSession). 로그인 인증은 아님
  final TmdbMovieDto movie;
  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;
  bool _disposed = false;

  Future<void> createRating({required int score, String? comment}) async {
    final id = memberId;
    if (id == null) {
      submitStatus = SubmitStatus.error;
      submitMessage = '먼저 회원가입을 완료해 주세요.';
      notifyListeners();
      return;
    }
    if (submitStatus == SubmitStatus.submitting) return;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();
    try {
      await _ratingService.createRating(
        memberId: id,
        request: CreateRatingRequest(
          movieId: movie.id, // 배열 index가 아닌 TMDB 영화 id
          score: score,
          comment: comment,
        ),
      );
      if (_disposed) return; // 화면을 떠난 뒤 도착한 응답은 반영하지 않음
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      submitMessage = writeErrorMessage(error);
    } on StateError catch (error) {
      // 201이 아닌 예상 밖 성공 응답
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
