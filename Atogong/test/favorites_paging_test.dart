import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/session/auth_session_bridge.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/core/utils/map_bounded.dart';
import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/favorites_view_model.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';

// 9주차: 네트워크 없이 돌릴 수 있도록 Service를 가짜로 바꿔 ViewModel의 판단만 확인

TmdbMovieDto _movie(int id) => TmdbMovieDto(
  id: id,
  title: '영화 $id',
  overview: '',
  posterPath: null,
  backdropPath: null,
  releaseDate: null,
  genreIds: const [],
  voteAverage: 0,
  popularity: 0,
);

TmdbMoviePageDto _page(int page, List<int> ids, {int totalPages = 3}) =>
    TmdbMoviePageDto(
      page: page,
      results: ids.map(_movie).toList(),
      totalPages: totalPages,
      totalResults: ids.length,
    );

DioException _apiError(int status, String code) {
  final options = RequestOptions(path: '/v8/favorites');
  return DioException(
    requestOptions: options,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: <String, dynamic>{
        'isSuccess': false,
        'code': code,
        'message': '',
        'result': null,
      },
    ),
  );
}

/// 호출마다 정해 둔 동작을 순서대로 실행하는 가짜 TMDB Service
class _FakeTmdb extends TmdbMovieService {
  _FakeTmdb() : super(Dio());

  final discoverCalls = <({int page, int? genreId})>[];
  final searchCalls = <({int page, String query})>[];
  Future<TmdbMoviePageDto> Function(int page, int? genreId)? onDiscover;
  Future<TmdbMoviePageDto> Function(int page, String query)? onSearch;
  Set<int> failingDetailIds = {};

  @override
  Future<TmdbMoviePageDto> discoverMovies({required int page, int? genreId}) {
    discoverCalls.add((page: page, genreId: genreId));
    return onDiscover!(page, genreId);
  }

  @override
  Future<TmdbMoviePageDto> searchMovies({
    required int page,
    required String query,
  }) {
    searchCalls.add((page: page, query: query));
    return onSearch!(page, query);
  }

  @override
  Future<TmdbMovieDto> fetchMovieDetail(int movieId) async {
    if (failingDetailIds.contains(movieId)) throw StateError('TMDB 실패');
    return _movie(movieId);
  }
}

class _FakeFavoriteApi extends FavoriteApiService {
  _FakeFavoriteApi() : super(Dio());

  Future<List<FavoriteResponseDto>> Function()? onFetch;
  Future<void> Function()? onAdd;
  Future<void> Function()? onDelete;
  bool serverIsFavorite = false;
  int checkCalls = 0;
  int addCalls = 0;

  @override
  Future<List<FavoriteResponseDto>> fetchMyFavorites() => onFetch!();

  @override
  Future<FavoriteCheckDto> checkFavorite({required int movieId}) async {
    checkCalls++;
    return FavoriteCheckDto(movieId: movieId, isFavorite: serverIsFavorite);
  }

  @override
  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    addCalls++;
    await onAdd?.call();
    return _favorite(movieId);
  }

  @override
  Future<void> deleteFavorite({required int movieId}) async {
    await onDelete?.call();
  }
}

FavoriteResponseDto _favorite(int movieId) => FavoriteResponseDto(
  favoriteId: movieId,
  movieId: movieId,
  createdAt: DateTime(2026, 11, 26),
);

void main() {
  group('mapBounded', () {
    test('결과는 입력 순서를 지키고 동시에 concurrency개까지만 실행한다', () async {
      var running = 0;
      var maxRunning = 0;
      final result = await mapBounded<int, int>(
        List.generate(12, (index) => index),
        5,
        (value) async {
          running++;
          if (running > maxRunning) maxRunning = running;
          // 뒤쪽 값이 먼저 끝나도록 지연을 다르게 줌
          await Future<void>.delayed(Duration(milliseconds: 12 - value));
          running--;
          return value * 10;
        },
      );

      expect(result, List.generate(12, (index) => index * 10));
      expect(maxRunning, 5);
    });

    test('입력이 비어 있으면 빈 목록을 돌려준다', () async {
      expect(await mapBounded<int, int>(const [], 5, (v) async => v), isEmpty);
    });
  });

  group('SessionGuard · AuthSessionBridge', () {
    test('같은 이메일로 다시 로그인해도 새 세션으로 취급한다', () {
      final guard = SessionGuard();
      final first = guard.startSession('a@example.com');
      expect(guard.isCurrent(first, 'a@example.com'), isTrue);

      guard.invalidate();
      final second = guard.startSession('a@example.com');
      expect(guard.isCurrent(first, 'a@example.com'), isFalse);
      expect(guard.isCurrent(second, 'a@example.com'), isTrue);
    });

    test('세션 버전·이메일이 바뀔 때만 세션을 다시 시작하고, 그 외 알림(닉네임 수정 등)에는 유지한다', () {
      final signals = ChangeNotifier();
      var version = 1;
      String? email;
      final bridge = AuthSessionBridge(
        authSignals: signals,
        sessionVersion: () => version,
        verifiedEmail: () => email,
      );
      expect(bridge.guard.accountId, isNull); // 내 정보가 오기 전

      email = 'a@example.com';
      signals.notifyListeners();
      final generation = bridge.guard.generation;
      expect(bridge.guard.accountId, 'a@example.com');

      signals.notifyListeners(); // 닉네임 수정처럼 세션과 무관한 알림
      expect(bridge.guard.generation, generation);

      version = 2; // 로그아웃
      email = null;
      signals.notifyListeners();
      expect(bridge.guard.accountId, isNull);
      expect(bridge.guard.isCurrent(generation, 'a@example.com'), isFalse);

      bridge.dispose();
      signals.dispose();
    });
  });

  group('PagedMoviesViewModel', () {
    test(
      '첫 page 뒤 더 보기는 중복 movieId를 빼고 이어 붙이고, 마지막 page에서 hasMore가 false가 된다',
      () async {
        final tmdb = _FakeTmdb()
          ..onDiscover = (page, _) async => switch (page) {
            1 => _page(1, [1, 2, 3], totalPages: 2),
            _ => _page(2, [3, 4], totalPages: 2), // 3은 앞 page와 중복
          };
        final vm = PagedMoviesViewModel(tmdbApi: tmdb);

        await vm.loadInitial();
        expect(vm.phase, LoadPhase.ready);
        expect(vm.movies.map((m) => m.id), [1, 2, 3]);
        expect(vm.hasMore, isTrue);

        await vm.loadNextPage();
        expect(vm.movies.map((m) => m.id), [1, 2, 3, 4]);
        expect(vm.hasMore, isFalse);

        await vm.loadNextPage(); // 더 요청하지 않음
        expect(tmdb.discoverCalls.length, 2);
        vm.dispose();
      },
    );

    test('다음 page 조회가 실패하면 기존 목록과 nextPage를 유지하고 같은 page를 다시 요청한다', () async {
      var failNext = true;
      final tmdb = _FakeTmdb()
        ..onDiscover = (page, _) async {
          if (page == 2 && failNext) throw StateError('네트워크 실패');
          return _page(page, [page * 10, page * 10 + 1]);
        };
      final vm = PagedMoviesViewModel(tmdbApi: tmdb);
      await vm.loadInitial();

      await vm.loadNextPage();
      expect(vm.loadMoreError, isNotNull);
      expect(vm.nextPage, 2);
      expect(vm.movies.map((m) => m.id), [10, 11]);
      expect(vm.phase, LoadPhase.ready);

      failNext = false;
      await vm.loadNextPage();
      expect(vm.loadMoreError, isNull);
      expect(tmdb.discoverCalls.map((c) => c.page), [1, 2, 2]);
      expect(vm.movies.map((m) => m.id), [10, 11, 20, 21]);
      expect(vm.nextPage, 3);
      vm.dispose();
    });

    test('장르를 바꾸면 이전 장르의 늦은 응답은 새 목록에 섞이지 않는다', () async {
      final slow = Completer<TmdbMoviePageDto>();
      final tmdb = _FakeTmdb()
        ..onDiscover = (page, genreId) =>
            genreId == 28 ? slow.future : Future.value(_page(1, [7, 8]));
      final vm = PagedMoviesViewModel(tmdbApi: tmdb);

      final first = vm.loadInitial(genreId: 28); // 느린 요청
      await vm.loadInitial(genreId: 35); // 장르 변경
      slow.complete(_page(1, [1, 2, 3])); // 이전 장르의 응답이 뒤늦게 도착
      await first;

      expect(vm.movies.map((m) => m.id), [7, 8]);
      vm.dispose();
    });

    test('검색어가 있으면 Search API를 쓰고, 화면을 벗어난 뒤 도착한 응답은 반영하지 않는다', () async {
      final slow = Completer<TmdbMoviePageDto>();
      final tmdb = _FakeTmdb()..onSearch = (page, query) => slow.future;
      final vm = PagedMoviesViewModel(tmdbApi: tmdb);

      final pending = vm.loadInitial(query: '  인터스텔라 ');
      expect(tmdb.searchCalls.single, (page: 1, query: '인터스텔라'));
      vm.dispose(); // 화면 이탈
      slow.complete(_page(1, [1]));
      await pending; // dispose 뒤 notifyListeners 오류가 나지 않아야 함

      expect(vm.movies, isEmpty);
    });
  });

  group('FavoritesViewModel', () {
    test('영화 정보 한 건 조회가 실패해도 목록 전체가 비지 않고 그 카드만 movie가 null이다', () async {
      final guard = SessionGuard()..startSession('a@example.com');
      final api = _FakeFavoriteApi()
        ..onFetch = () async => [_favorite(550), _favorite(999), _favorite(13)];
      final tmdb = _FakeTmdb()..failingDetailIds = {999};
      final vm = FavoritesViewModel(
        favoriteApi: api,
        tmdbApi: tmdb,
        sessionGuard: guard,
        accountId: 'a@example.com',
      );

      await vm.refresh();

      expect(vm.phase, LoadPhase.ready);
      expect(vm.items.map((i) => i.favorite.movieId), [550, 999, 13]);
      expect(vm.items.map((i) => i.hasMovie), [true, false, true]);
      vm.dispose();
    });

    test('빈 배열이면 empty, 목록 조회 자체가 실패하면 error로 구분한다', () async {
      final guard = SessionGuard()..startSession('a@example.com');
      final api = _FakeFavoriteApi()..onFetch = () async => [];
      final vm = FavoritesViewModel(
        favoriteApi: api,
        tmdbApi: _FakeTmdb(),
        sessionGuard: guard,
        accountId: 'a@example.com',
      );

      await vm.refresh();
      expect(vm.phase, LoadPhase.empty);

      api.onFetch = () async => throw StateError('네트워크 실패');
      await vm.refresh();
      expect(vm.phase, LoadPhase.error);
      vm.dispose();
    });

    test('계정이 바뀐 뒤 도착한 이전 계정의 응답·401은 화면과 세션을 건드리지 않는다', () async {
      final guard = SessionGuard()..startSession('a@example.com');
      final slow = Completer<List<FavoriteResponseDto>>();
      var expiredCalls = 0;
      final api = _FakeFavoriteApi()..onFetch = () => slow.future;
      final vm = FavoritesViewModel(
        favoriteApi: api,
        tmdbApi: _FakeTmdb(),
        sessionGuard: guard,
        accountId: 'a@example.com',
        onSessionExpired: () async => expiredCalls++,
      );

      final pending = vm.refresh();
      guard.invalidate(); // 로그아웃
      guard.startSession('b@example.com'); // 다른 계정 로그인
      slow.completeError(_apiError(401, 'AUTH401_4')); // A 계정 요청의 401이 뒤늦게 도착
      await pending;

      expect(vm.items, isEmpty);
      expect(expiredCalls, 0);
      vm.dispose();
    });

    test('만료·무효 토큰(AUTH401_2/3/4)이면 세션 정리를 요청하고, 403은 요청하지 않는다', () async {
      final guard = SessionGuard()..startSession('a@example.com');
      var expiredCalls = 0;
      final api = _FakeFavoriteApi()
        ..onFetch = () async => throw _apiError(401, 'AUTH401_3');
      final vm = FavoritesViewModel(
        favoriteApi: api,
        tmdbApi: _FakeTmdb(),
        sessionGuard: guard,
        accountId: 'a@example.com',
        onSessionExpired: () async => expiredCalls++,
      );

      await vm.refresh();
      expect(expiredCalls, 1);

      api.onFetch = () async => throw _apiError(403, 'COMMON403');
      await vm.refresh();
      expect(expiredCalls, 1);
      expect(vm.phase, LoadPhase.error);
      vm.dispose();
    });
  });

  group('FavoriteDetailViewModel', () {
    FavoriteDetailViewModel create(_FakeFavoriteApi api, SessionGuard guard) {
      return FavoriteDetailViewModel(
        movieId: 550,
        favoriteApi: api,
        sessionGuard: guard,
        accountId: 'a@example.com',
      );
    }

    test('여부 조회 전에는 toggle이 요청을 보내지 않고, 등록에 성공한 뒤에만 isFavorite가 바뀐다', () async {
      final guard = SessionGuard()..startSession('a@example.com');
      final api = _FakeFavoriteApi();
      final vm = create(api, guard);

      await vm.toggle();
      expect(api.addCalls, 0);

      await vm.load();
      expect(vm.hasLoadedStatus, isTrue);
      expect(vm.isFavorite, isFalse);

      await vm.toggle();
      expect(api.addCalls, 1);
      expect(vm.isFavorite, isTrue);
      expect(vm.isSaving, isFalse);
      vm.dispose();
    });

    test('등록이 FAVORITE409_1이면 POST를 반복하지 않고 서버의 현재 여부로 맞춘다', () async {
      final guard = SessionGuard()..startSession('a@example.com');
      final api = _FakeFavoriteApi();
      final vm = create(api, guard);
      await vm.load(); // 화면은 "즐겨찾기 아님"으로 알고 있음

      api.serverIsFavorite = true; // 서버에는 이미 등록돼 있음
      api.onAdd = () async => throw _apiError(409, 'FAVORITE409_1');
      await vm.toggle();

      expect(api.addCalls, 1);
      expect(api.checkCalls, 2); // 첫 조회 + 동기화 조회
      expect(vm.isFavorite, isTrue);
      expect(vm.errorMessage, isNull);
      vm.dispose();
    });

    test('네트워크 실패면 이전 아이콘 상태를 유지하고 실패 안내를 남긴다', () async {
      final guard = SessionGuard()..startSession('a@example.com');
      final api = _FakeFavoriteApi()..serverIsFavorite = true;
      final vm = create(api, guard);
      await vm.load();

      api.onDelete = () async => throw DioException(
        requestOptions: RequestOptions(path: '/v8/favorites/550'),
        type: DioExceptionType.connectionTimeout,
      );
      await vm.toggle();

      expect(vm.isFavorite, isTrue);
      expect(vm.errorMessage, '즐겨찾기 해제에 실패했습니다.');
      vm.dispose();
    });
  });
}
