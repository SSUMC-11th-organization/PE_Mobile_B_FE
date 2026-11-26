import 'package:dio/dio.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

/// 서버 오류 응답({code,message})을 가진 DioException을 만듭니다.
DioException apiError(String code, {int status = 400}) {
  final options = RequestOptions(path: '/test');
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: {'isSuccess': false, 'code': code, 'message': '서버 메시지($code)'},
    ),
  );
}

/// 응답이 없는 네트워크 오류.
DioException networkError() => DioException(
      requestOptions: RequestOptions(path: '/test'),
      type: DioExceptionType.connectionError,
    );

class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage([this.token]);

  String? token;

  @override
  Future<void> saveAccessToken(String value) async => token = value;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<void> deleteAccessToken() async => token = null;
}

class FakeAuthApi implements AuthApiService {
  Object? error;

  @override
  Future<LoginResult> login(LoginRequest request) async {
    if (error != null) throw error!;
    return const LoginResult(nickname: '닉', accessToken: 'fake-token');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MemberInfo fakeMember({String nickname = '무비러버'}) => MemberInfo(
      email: 'a@b.co',
      nickname: nickname,
      createdAt: DateTime(2026, 10, 10),
    );

class FakeMemberApi implements MemberApiService {
  Object? fetchError;
  Object? updateError;
  int updateCalls = 0;

  @override
  Future<MemberInfo> fetchMe() async {
    if (fetchError != null) throw fetchError!;
    return fakeMember();
  }

  @override
  Future<MemberInfo> updateNickname(String nickname) async {
    updateCalls++;
    if (updateError != null) throw updateError!;
    return fakeMember(nickname: nickname);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RatingDto fakeRating({int id = 1, int movieId = 42, int score = 5, String? comment}) =>
    RatingDto(
      ratingId: id,
      movieId: movieId,
      score: score,
      comment: comment,
      createdAt: DateTime(2026, 11, 4),
    );

class FakeRatingApi implements RatingApiService {
  Object? error;

  @override
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    if (error != null) throw error!;
    return fakeRating(movieId: request.movieId, score: request.score, comment: request.comment);
  }

  @override
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    if (error != null) throw error!;
    return fakeRating(id: ratingId, score: score, comment: comment);
  }

  @override
  Future<void> deleteRating(int ratingId) async {
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTmdb implements TmdbMovieService {
  @override
  Future<TmdbMoviePageDto> discoverMovies({required int page, int? genreId}) async =>
      const TmdbMoviePageDto(page: 1, results: [], totalPages: 1, totalResults: 0);

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async =>
      const TmdbMoviePageDto(page: 1, results: [], totalPages: 1, totalResults: 0);

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async => const [];

  @override
  Future<TmdbMovieDto?> findMovieById(int movieId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TmdbMovieDto fakeMovie({int id = 42}) => TmdbMovieDto(
      id: id,
      title: '테스트 영화',
      overview: '줄거리입니다.',
      posterPath: null,
      backdropPath: null,
      releaseDate: '2024-05-01',
      genreIds: const [18],
      voteAverage: 8.4,
      popularity: 120.5,
    );

class FakeFavoriteApi implements FavoriteApiService {
  Object? writeError;
  bool serverFavorite = false;
  List<int> favoriteIds = [];

  FavoriteResponseDto _dto(int movieId) => FavoriteResponseDto(
        favoriteId: movieId,
        movieId: movieId,
        createdAt: DateTime(2026, 11, 26),
      );

  @override
  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    if (writeError != null) throw writeError!;
    serverFavorite = true;
    return _dto(movieId);
  }

  @override
  Future<void> deleteFavorite({required int movieId}) async {
    if (writeError != null) throw writeError!;
    serverFavorite = false;
  }

  @override
  Future<FavoriteCheckDto> checkFavorite({required int movieId}) async =>
      FavoriteCheckDto(movieId: movieId, isFavorite: serverFavorite);

  @override
  Future<List<FavoriteResponseDto>> fetchMyFavorites() async =>
      favoriteIds.map(_dto).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
