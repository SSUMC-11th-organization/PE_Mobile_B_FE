import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import '../services/genre_preference.dart';

enum MovieListStatus { idle, loading, success, empty, error }

// 영화 목록 탭 상태 — TMDB 장르 목록 + 선택 장르의 Discover 결과(최대 30편)
class MovieListViewModel extends ChangeNotifier {
  MovieListViewModel(this._service, {GenrePreference? genrePreference})
    : _genrePreference = genrePreference ?? GenrePreference();

  static const maxMovies = 30;

  final TmdbMovieService _service;
  final GenrePreference _genrePreference;

  MovieListStatus _status = MovieListStatus.idle;
  String? _message;
  List<TmdbGenreDto> _genres = const [];
  List<TmdbMovieDto> _movies = const [];
  int? _selectedGenreId; // null이면 '전체'

  // 요청마다 1씩 증가 — 응답이 왔을 때 최신 요청이 아니면 버림
  int _requestVersion = 0;
  bool _disposed = false;

  MovieListStatus get status => _status;
  String? get message => _message;
  List<TmdbGenreDto> get genres => _genres;
  List<TmdbMovieDto> get movies => _movies;
  int? get selectedGenreId => _selectedGenreId;
  bool get isLoading => _status == MovieListStatus.loading;

  // 생성 직후 한 번 호출 (라우트의 ChangeNotifierProvider.create에서)
  Future<void> loadInitial() async {
    final version = _startRequest();
    try {
      final genres = await _service.fetchGenres();
      final savedGenreId = await _readSavedGenreId();
      if (!_isCurrent(version)) return;

      _genres = genres;
      // 저장된 장르가 현재 장르 목록에 없으면 '전체'로
      _selectedGenreId = genres.any((g) => g.id == savedGenreId)
          ? savedGenreId
          : null;
      _notify(); // 영화 로딩 중에도 장르 Chip은 먼저 보여줌

      final movies = await fetchUpToThirtyMovies(genreId: _selectedGenreId);
      if (!_isCurrent(version)) return;
      _applyMovies(movies);
    } on TmdbApiException catch (e) {
      _applyError(version, e.message);
    } on DioException {
      _applyError(version, null);
    }
  }

  // 장르 변경 — 로컬 필터가 아니라 with_genres로 page 1부터 다시 조회
  Future<void> selectGenre(int? genreId) async {
    if (isLoading) return; // 로딩 중에는 장르 변경 막음
    if (genreId == _selectedGenreId && _status == MovieListStatus.success) {
      return; // 이미 보고 있는 장르를 다시 누른 경우
    }

    _selectedGenreId = genreId;
    _saveGenreId(genreId);
    await _reloadMovies();
  }

  // 에러 화면의 '다시 시도' — 장르 목록부터 실패했으면 처음부터, 아니면 현재 장르만 재조회
  Future<void> retry() async {
    if (isLoading) return;
    if (_genres.isEmpty) {
      await loadInitial();
    } else {
      await _reloadMovies();
    }
  }

  // Discover를 page 1부터 넘기며 최대 30편까지 모음
  // - TMDB id 기준 중복 제거 (페이지 사이에 순위가 바뀌면 같은 영화가 다시 나올 수 있음)
  // - 한 페이지 개수는 응답에 맡김 (하드코딩하지 않음)
  // - 30편이 차거나, 마지막 페이지(totalPages)거나, results가 비면 중단
  Future<List<TmdbMovieDto>> fetchUpToThirtyMovies({int? genreId}) async {
    final version = _requestVersion;
    final moviesById = <int, TmdbMovieDto>{}; // Dart Map은 넣은 순서(인기순)를 유지
    var page = 1;

    while (moviesById.length < maxMovies) {
      final result = await _service.discoverMovies(
        page: page,
        genreId: genreId,
      );
      if (!_isCurrent(version)) break; // 더 새로운 요청이 시작됐으면 남은 페이지는 요청하지 않음
      if (result.results.isEmpty) break;

      for (final movie in result.results) {
        moviesById.putIfAbsent(movie.id, () => movie);
        if (moviesById.length >= maxMovies) break;
      }

      if (page >= result.totalPages) break;
      page++;
    }
    return moviesById.values.toList();
  }

  Future<void> _reloadMovies() async {
    final version = _startRequest();
    try {
      final movies = await fetchUpToThirtyMovies(genreId: _selectedGenreId);
      if (!_isCurrent(version)) return;
      _applyMovies(movies);
    } on TmdbApiException catch (e) {
      _applyError(version, e.message);
    } on DioException {
      _applyError(version, null);
    }
  }

  int _startRequest() {
    final version = ++_requestVersion;
    _status = MovieListStatus.loading;
    _message = null;
    _notify();
    return version;
  }

  bool _isCurrent(int version) => !_disposed && version == _requestVersion;

  void _applyMovies(List<TmdbMovieDto> movies) {
    _movies = movies;
    _status = movies.isEmpty ? MovieListStatus.empty : MovieListStatus.success;
    _notify();
  }

  void _applyError(int version, String? message) {
    if (!_isCurrent(version)) return; // 늦게 실패한 이전 요청은 무시
    _movies = const [];
    _status = MovieListStatus.error;
    _message = message ?? '영화를 불러오지 못했습니다.';
    _notify();
  }

  // 저장값 읽기/쓰기 실패는 목록 표시에 영향이 없도록 무시
  Future<int?> _readSavedGenreId() async {
    try {
      return await _genrePreference.read();
    } catch (_) {
      return null;
    }
  }

  void _saveGenreId(int? genreId) {
    _genrePreference.save(genreId).catchError((Object _) {});
  }

  // dispose된 뒤에는 notify하지 않음
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
