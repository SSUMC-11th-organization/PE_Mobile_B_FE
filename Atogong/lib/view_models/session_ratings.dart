import 'package:flutter/foundation.dart';

import '../data/models/rating_dto.dart';
import 'auth_view_model.dart';

/// 현재 로그인 세션에서 등록한 평점 목록 (메모리 전용).
/// v7 로그인·내 정보 응답에는 memberId가 없고 토큰 기반 "내 평점 목록 GET"도 없어서,
/// 등록 응답으로 받은 Rating만 모아 두고 이번 세션 안에서 수정·삭제함.
/// 한계: 앱을 재시작하거나 다시 로그인하면 이전에 남긴 평점은 목록에 복원되지 않음 (서버에는 그대로 있음)
class SessionRatings extends ChangeNotifier {
  SessionRatings(this._auth) : _sessionVersion = _auth.sessionVersion {
    _auth.addListener(_onAuthChanged);
  }

  final AuthViewModel _auth;
  int _sessionVersion;
  List<RatingDto> _ratings = const [];

  List<RatingDto> get ratings => List.unmodifiable(_ratings);

  // 로그아웃·만료·다른 계정 로그인으로 세션이 바뀌면 이전 회원의 평점을 비움
  void _onAuthChanged() {
    if (_auth.sessionVersion == _sessionVersion) return;
    _sessionVersion = _auth.sessionVersion;
    if (_ratings.isEmpty) return;
    _ratings = const [];
    notifyListeners();
  }

  /// 등록 응답으로 받은 Rating을 맨 위에 추가
  void add(RatingDto rating) {
    _ratings = [
      rating,
      ..._ratings.where((item) => item.ratingId != rating.ratingId),
    ];
    notifyListeners();
  }

  /// 수정 응답으로 받은 Rating으로 같은 ratingId 항목을 교체
  void replace(RatingDto rating) {
    _ratings = [
      for (final item in _ratings)
        if (item.ratingId == rating.ratingId) rating else item,
    ];
    notifyListeners();
  }

  void remove(int ratingId) {
    _ratings = _ratings.where((item) => item.ratingId != ratingId).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
