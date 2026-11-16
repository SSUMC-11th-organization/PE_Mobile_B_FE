import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'auth_view_model.dart';
import 'session_ratings.dart';
import 'submit_status.dart';

/// 영화 상세 화면: 현재 영화 DTO와 평점 "등록" 상태만 관리 (수정·삭제는 MyRatingsViewModel).
/// 8주차: memberId 인자 제거. 누구의 평점인지는 Authorization 헤더의 토큰으로 서버가 판단
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(
    this._ratingService,
    this._auth,
    this._sessionRatings,
    this.movie,
  );
  final RatingApiService _ratingService;
  final AuthViewModel _auth;
  final SessionRatings _sessionRatings;
  final TmdbMovieDto movie;
  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;
  bool _disposed = false;

  Future<void> createRating({required int score, String? comment}) async {
    if (submitStatus == SubmitStatus.submitting) return;
    final sessionVersion = _auth.sessionVersion; // 요청을 보낸 시점의 세션
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();
    try {
      final rating = await _ratingService.createRating(
        CreateRatingRequest(
          movieId: movie.id, // 배열 index가 아닌 TMDB 영화 id
          score: score,
          comment: comment,
        ),
      );
      // 로그아웃·회원 전환 뒤 늦게 도착한 응답은 반영하지 않음
      if (sessionVersion != _auth.sessionVersion) return;
      // 등록 result의 Rating 객체를 보관 → "내가 등록한 평점"에서 수정·삭제
      _sessionRatings.add(rating);
      if (_disposed) return;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_disposed || sessionVersion != _auth.sessionVersion) return;
      submitStatus = SubmitStatus.error;
      if (isSessionExpiredCode(apiErrorCode(error))) {
        // 보호 요청의 401: 세션을 정리하면 Router가 /login으로 보내고, 로그인 화면이 만료 안내를 띄움
        submitMessage = '로그인이 만료됐어요. 다시 로그인해 주세요.';
        await _auth.expireSession();
      } else {
        // 403·409 등은 안내만 하고 로그인 상태를 유지
        submitMessage = writeErrorMessage(error);
      }
    } on StateError catch (error) {
      // 성공 status인데 result 모양이 계약과 다른 경우
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
