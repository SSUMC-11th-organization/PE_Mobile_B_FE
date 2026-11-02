import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';

enum MovieHomeStatus { idle, loading, success, empty, error }

// 홈 화면 상태 — 인기 영화 상위 5개를 불러와 보관
class MovieHomeViewModel extends ChangeNotifier {
  MovieHomeViewModel(this._service);

  static const _popularLimit = 5;

  final TmdbMovieService _service;

  MovieHomeStatus _status = MovieHomeStatus.idle;
  List<TmdbMovieDto> _movies = const [];
  String? _errorMessage;
  bool _disposed = false;

  MovieHomeStatus get status => _status;
  List<TmdbMovieDto> get popularMovies => _movies;
  String? get errorMessage => _errorMessage;

  // 생성 직후 한 번 호출 (라우트의 ChangeNotifierProvider.create에서) — build에서 호출하지 않음
  Future<void> loadPopular() async {
    if (_status == MovieHomeStatus.loading) return; // 중복 요청 방지

    _status = MovieHomeStatus.loading;
    _errorMessage = null;
    _notify();

    try {
      final page = await _service.fetchPopular();
      // take는 개수가 5개보다 적어도 범위 오류 없이 있는 만큼만 가져옴
      _movies = page.results.take(_popularLimit).toList();
      _status = _movies.isEmpty
          ? MovieHomeStatus.empty
          : MovieHomeStatus.success;
    } on TmdbApiException catch (e) {
      // TmdbMovieService가 DioException을 TmdbApiException으로 감싸서 던짐
      _movies = const [];
      _status = MovieHomeStatus.error;
      _errorMessage = e.message;
    } on DioException {
      _movies = const [];
      _status = MovieHomeStatus.error;
      _errorMessage = '영화를 불러오지 못했습니다.';
    }
    _notify();
  }

  // 요청 중에 화면을 벗어나 dispose된 뒤에는 notify하지 않음
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
