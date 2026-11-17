import 'package:flutter/material.dart';
import 'package:jay/data/models/rating_dto.dart';

/// 현재 로그인 세션에서 등록한 Rating을 보관합니다.
///
/// v7에는 토큰 기반 "내 평점 목록 GET"이 없고, 로그인·내 정보 응답에도 memberId가 없습니다.
/// 그래서 등록 response로 받은 Rating만 현재 세션에서 수정·삭제합니다.
/// 앱 재시작 뒤 기존 내 평점 전체 복원은 API 계약이 확인될 때까지 지원하지 않습니다.
///
/// AuthViewModel.sessionVersion이 바뀌면(로그인·로그아웃·만료·재시작 복원) 이전 세션 값을 비웁니다.
class SessionRatingStore extends ChangeNotifier {
  final Map<int, RatingDto> _byMovieId = {};
  int? _sessionVersion;

  /// ChangeNotifierProxyProvider의 update에서 호출됩니다. build 중이므로 notify하지 않습니다.
  void syncSession(int sessionVersion) {
    if (_sessionVersion == sessionVersion) return;
    _sessionVersion = sessionVersion;
    _byMovieId.clear();
  }

  int? get sessionVersion => _sessionVersion;

  List<RatingDto> get ratings => _byMovieId.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  RatingDto? ratingForMovie(int movieId) => _byMovieId[movieId];

  /// [sessionVersion]은 요청 전에 읽어 둔 값입니다. 그 사이 세션이 바뀌었으면 반영하지 않습니다.
  void put(RatingDto rating, {required int sessionVersion}) {
    if (sessionVersion != _sessionVersion) return;
    _byMovieId[rating.movieId] = rating;
    notifyListeners();
  }

  void removeByRatingId(int ratingId, {required int sessionVersion}) {
    if (sessionVersion != _sessionVersion) return;
    _byMovieId.removeWhere((_, rating) => rating.ratingId == ratingId);
    notifyListeners();
  }
}
