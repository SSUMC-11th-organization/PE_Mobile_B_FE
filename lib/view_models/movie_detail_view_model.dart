import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/api_response.dart';
import '../data/services/rating_api_service.dart';
import 'auth_view_model.dart';
import 'session_ratings_store.dart';
import 'sign_up_view_model.dart' show SubmitStatus;

// 영화 상세 화면 상태 — 영화 정보 + 평점 등록(POST /v7/ratings, 보호 API) 요청 상태
// 등록 성공 응답의 Rating은 이번 세션 평점 목록(SessionRatingsStore)에 담음
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._ratingService, this._store, this._auth, this.movie);

  final RatingApiService _ratingService;
  final SessionRatingsStore _store;
  final AuthViewModel _auth; // sessionVersion 확인용
  final TmdbMovieDto movie;
  bool _disposed = false;

  // idle로 끝나면 세션 만료/세션 변경으로 결과를 버린 것 → 화면은 문구 없이 진행 중 상태만 해제
  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage; // 실패 시 Dialog 입력칸 아래에 보여줄 문구

  Future<void> createRating({required int score, String? comment}) async {
    if (submitStatus == SubmitStatus.submitting) return; // 제출 중 중복 호출 무시
    final version = _auth.sessionVersion; // 요청을 시작한 세션
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    _notify();
    try {
      final rating = await _ratingService.createRating(
        CreateRatingRequest(movieId: movie.id, score: score, comment: comment),
      );
      if (_auth.sessionVersion != version) {
        // 로그아웃/만료/사용자 전환 뒤 늦게 온 응답 → 반영하지 않음
        submitStatus = SubmitStatus.idle;
      } else {
        _store.add(rating, movie: movie);
        submitStatus = SubmitStatus.success;
      }
    } on DioException catch (e) {
      final info = describeRatingError(e);
      if (info.isSilent || _auth.sessionVersion != version) {
        submitStatus = SubmitStatus.idle;
      } else {
        submitStatus = SubmitStatus.error;
        submitMessage = info.message;
      }
    } on InvalidApiResponseException {
      submitStatus = SubmitStatus.error;
      submitMessage = '등록 결과를 확인하지 못했습니다. 마이페이지의 "평점 기록"에서 확인해 주세요.';
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
