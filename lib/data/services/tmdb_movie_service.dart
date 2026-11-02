import 'package:dio/dio.dart';

import '../../core/network/tmdb_client.dart';
import '../models/json_parsers.dart';
import '../models/tmdb_genre_dto.dart';
import '../models/tmdb_movie_page_dto.dart';

// TMDB 요청 실패를 화면에서 다루기 쉬운 형태로 감싼 예외 (토큰·헤더 정보는 담지 않음)
class TmdbApiException implements Exception {
  const TmdbApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'TmdbApiException($statusCode): $message';
}

// TMDB 영화 API 호출 — 응답 JSON을 DTO로 변환해서 돌려줌
class TmdbMovieService {
  TmdbMovieService({TmdbClient? client}) : _dio = (client ?? TmdbClient()).dio;

  final Dio _dio;

  // 인기 영화 목록 (GET /movie/popular)
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    final json = await _getJson('/movie/popular', {'page': page});
    return TmdbMoviePageDto.fromJson(json);
  }

  // 조건 검색 (GET /discover/movie) — genreId가 null이면 전체 장르
  Future<TmdbMoviePageDto> discoverMovies({
    int page = 1,
    int? genreId,
    String sortBy = 'popularity.desc',
  }) async {
    final json = await _getJson('/discover/movie', {
      'page': page,
      'sort_by': sortBy,
      'include_adult': false,
      'with_genres': ?genreId,
    });
    return TmdbMoviePageDto.fromJson(json);
  }

  // 영화 장르 목록 (GET /genre/movie/list) — 응답은 { genres: [...] }
  Future<List<TmdbGenreDto>> fetchGenres() async {
    final json = await _getJson('/genre/movie/list');
    return parseObjectList(json['genres'], TmdbGenreDto.fromJson);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, [
    Map<String, dynamic>? queryParameters,
  ]) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const TmdbApiException('응답 형식이 올바르지 않습니다.');
      }
      return data;
    } on DioException catch (e) {
      throw TmdbApiException(
        _messageFor(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  String _messageFor(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '서버 응답이 지연되고 있습니다.';
      case DioExceptionType.connectionError:
        return '네트워크 연결을 확인해 주세요.';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == 401) return 'TMDB 인증에 실패했습니다. 토큰을 확인해 주세요.';
        if (status == 404) return '요청한 정보를 찾을 수 없습니다.';
        if (status == 429) return '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';
        return '영화를 불러오지 못했습니다. ($status)';
      default:
        return '영화를 불러오지 못했습니다.';
    }
  }
}
