import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jay/core/network/api_error.dart';
import 'package:jay/data/models/rating_dto.dart';
import 'package:jay/data/models/rating_request.dart';
import 'package:jay/data/models/tmdb_movie_dto.dart';
import 'package:jay/data/services/rating_api_service.dart';
import 'package:jay/view_models/auth_view_model.dart';
import 'package:jay/view_models/session_rating_store.dart';
import 'package:jay/view_models/signup_view_model.dart';

/// 영화 상세의 평점 등록·수정·삭제 (v7 토큰 기반)
///
/// - 401(AUTH401_2/3/4): 세션을 정리하고 Router가 /login으로 보냅니다.
/// - 403·409 등: 안내만 하고 로그인 상태를 유지합니다.
/// - 로그아웃·회원 전환 뒤 늦게 도착한 응답은 sessionVersion으로 걸러냅니다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._ratingService, this._auth, this._store, this.movie) {
    _store.addListener(_onStoreChanged);
  }

  final RatingApiService _ratingService;
  final AuthViewModel _auth;
  final SessionRatingStore _store;
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;
  bool _disposed = false;

  /// 현재 세션에서 이 영화에 등록한 평점 (등록 response의 Rating 객체)
  RatingDto? get myRating => _store.ratingForMovie(movie.id);

  bool get canWrite => _auth.status == AuthStatus.signedIn;

  Future<void> createRating({required int score, String? comment}) {
    return _run(
      (service) => service.createRating(
        CreateRatingRequest(movieId: movie.id, score: score, comment: comment),
      ),
    );
  }

  Future<void> updateRating({required int score, String? comment}) {
    final current = myRating;
    if (current == null) return Future.value();
    return _run(
      (service) => service.updateRating(
        ratingId: current.ratingId,
        score: score,
        comment: comment,
      ),
    );
  }

  Future<void> deleteRating() async {
    final current = myRating;
    if (current == null) return;
    await _run((service) async {
      await service.deleteRating(current.ratingId);
      return null;
    }, deletedRatingId: current.ratingId);
  }

  Future<void> _run(
    Future<RatingDto?> Function(RatingApiService service) request, {
    int? deletedRatingId,
  }) async {
    if (submitStatus == SubmitStatus.submitting || !canWrite) return;
    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    _notify();
    try {
      final result = await request(_ratingService);
      if (!_isCurrent(version)) return;
      if (deletedRatingId != null) {
        _store.removeByRatingId(deletedRatingId, sessionVersion: version);
      } else if (result != null) {
        // 등록·수정 result의 Rating 객체로 현재 작업 카드를 갱신합니다.
        _store.put(result, sessionVersion: version);
      }
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      submitStatus = SubmitStatus.error;
      submitMessage = writeErrorMessage(error);
      final code = apiErrorCode(error);
      if (isSessionExpiredCode(code)) {
        await _auth.expireSession(version: version);
        return;
      }
      // 이미 지워진 평점이면 카드도 정리합니다.
      if (code == 'RATING404_1' && myRating != null) {
        _store.removeByRatingId(myRating!.ratingId, sessionVersion: version);
      }
    } catch (_) {
      if (!_isCurrent(version)) return;
      submitStatus = SubmitStatus.error;
      submitMessage = '응답을 확인하지 못했어요. 잠시 후 다시 시도해 주세요.';
    }
    _notify();
  }

  bool _isCurrent(int version) =>
      !_disposed && version == _auth.sessionVersion;

  void _onStoreChanged() => _notify();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }
}
