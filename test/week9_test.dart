import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/auth_interceptor.dart';
import 'package:movielog/core/session/auth_session_bridge.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/favorites_view_model.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';

import 'support/fakes.dart';

TmdbMoviePageDto _page(int page, List<int> ids, {int total = 3}) =>
    TmdbMoviePageDto(
      page: page,
      results: [for (final id in ids) fakeMovie(id: id)],
      totalPages: total,
      totalResults: ids.length,
    );

/// 요청마다 Completer를 남겨 응답 순서를 테스트가 정합니다.
class _ManualTmdb extends FakeTmdb {
  final pages = <int>[];
  final replies = <Completer<TmdbMoviePageDto>>[];

  Future<TmdbMoviePageDto> _record(int page) {
    pages.add(page);
    replies.add(Completer());
    return replies.last.future;
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({required int page, int? genreId}) =>
      _record(page);

  @override
  Future<TmdbMoviePageDto> searchMovies({
    required int page,
    required String query,
  }) =>
      _record(page);
}

class _PartialTmdb extends FakeTmdb {
  bool fail = true;

  @override
  Future<TmdbMovieDto> fetchMovieDetail(int movieId) async {
    if (movieId == 2 && fail) throw networkError();
    return fakeMovie(id: movieId);
  }
}

class _Signals extends ChangeNotifier {
  void ping() => notifyListeners();
}

SessionGuard _guard() => SessionGuard()..startSession('a@b.co');

void main() {
  group('PagedMoviesViewModel', () {
    test('다음 page 실패 후 같은 page를 다시 요청하고 중복 영화는 제외한다', () async {
      final api = _ManualTmdb();
      final vm = PagedMoviesViewModel(api);
      var done = vm.loadInitial();
      api.replies.last.complete(_page(1, [1, 2], total: 2));
      await done;

      done = vm.loadNextPage();
      api.replies.last.completeError(networkError());
      await done;
      expect(vm.loadMoreError, isNotNull);
      expect(vm.movies.length, 2);
      expect(vm.nextPage, 2);

      done = vm.loadNextPage();
      api.replies.last.complete(_page(2, [2, 3], total: 2));
      await done;
      expect(api.pages, [1, 2, 2]);
      expect(vm.movies.map((m) => m.id), [1, 2, 3]);
      expect(vm.hasMore, isFalse);
    });

    test('늦게 도착한 이전 검색어의 응답은 버린다', () async {
      final api = _ManualTmdb();
      final vm = PagedMoviesViewModel(api);
      final old = vm.loadInitial(query: '이전');
      final latest = vm.loadInitial(query: '최신');
      api.replies[1].complete(_page(1, [20]));
      api.replies[0].complete(_page(1, [10]));
      await Future.wait([old, latest]);
      expect(vm.movies.map((m) => m.id), [20]);
    });

    test('total_pages가 500을 넘어도 500까지만 요청한다', () async {
      final api = _ManualTmdb();
      final vm = PagedMoviesViewModel(api);
      final done = vm.loadInitial();
      api.replies.last.complete(_page(1, [1], total: 9999));
      await done;
      expect(vm.totalPages, 500);
    });
  });

  group('FavoriteDetailViewModel', () {
    var expired = 0;
    setUp(() => expired = 0);

    FavoriteDetailViewModel create(FakeFavoriteApi api, SessionGuard guard) =>
        FavoriteDetailViewModel(
          movieId: 42,
          favoriteApi: api,
          sessionGuard: guard,
          accountId: 'a@b.co',
          onSessionExpired: () async => expired++,
        );

    test('FAVORITE409_1은 서버 상태를 다시 조회해 맞춘다', () async {
      final api = FakeFavoriteApi();
      final vm = create(api, _guard());
      await vm.load();
      api
        ..serverFavorite = true
        ..writeError = apiError('FAVORITE409_1', status: 409);
      await vm.toggle();
      expect(vm.isFavorite, isTrue);
      expect(vm.errorMessage, isNull);
    });

    test('네트워크 실패는 이전 상태를 유지하고 로그아웃하지 않는다', () async {
      final api = FakeFavoriteApi()..serverFavorite = true;
      final vm = create(api, _guard());
      await vm.load();
      api.writeError = networkError();
      expect(await vm.toggle(), '즐겨찾기 해제에 실패했습니다.');
      expect(vm.isFavorite, isTrue);
      expect(expired, 0);
    });

    test('AUTH401_3은 세션을 만료시키고 안내 문구를 만들지 않는다', () async {
      final api = FakeFavoriteApi();
      final vm = create(api, _guard());
      await vm.load();
      api.writeError = apiError('AUTH401_3', status: 401);
      expect(await vm.toggle(), isNull);
      expect(expired, 1);
    });

    test('이전 세션의 늦은 401은 현재 계정을 로그아웃시키지 않는다', () async {
      final api = FakeFavoriteApi();
      final guard = _guard();
      final vm = create(api, guard);
      await vm.load();
      api.writeError = apiError('AUTH401_3', status: 401);
      final pending = vm.toggle();
      guard.startSession('other@b.co');
      await pending;
      expect(expired, 0);
    });
  });

  test('FavoritesViewModel: 한 건 실패는 그 카드만 placeholder가 되고 재조회된다', () async {
    final tmdb = _PartialTmdb();
    final vm = FavoritesViewModel(
      favoriteApi: FakeFavoriteApi()..favoriteIds = [1, 2, 3],
      tmdbApi: tmdb,
      sessionGuard: _guard(),
      accountId: 'a@b.co',
      onSessionExpired: () async {},
    );
    await vm.refresh();
    expect(vm.phase, LoadPhase.ready);
    expect(vm.items.map((i) => i.movie?.id), [1, null, 3]);

    tmdb.fail = false;
    await vm.retryMovie(2);
    expect(vm.items.map((i) => i.movie?.id), [1, 2, 3]);
  });

  test('AuthSessionBridge: 같은 계정이라도 재로그인하면 새 세션이다', () {
    final signals = _Signals();
    var version = 1;
    String? email = 'a@b.co';
    final bridge = AuthSessionBridge(
      authSignals: signals,
      sessionVersion: () => version,
      verifiedEmail: () => email,
    );
    final first = bridge.guard.generation;

    signals.ping(); // 닉네임 변경 등: 세션 유지
    expect(bridge.guard.generation, first);

    version = 2;
    signals.ping();
    expect(bridge.guard.isCurrent(first, 'a@b.co'), isFalse);

    email = null;
    signals.ping();
    expect(bridge.guard.accountId, isNull);
    bridge.dispose();
  });

  test('AuthInterceptor: v8 즐겨찾기에는 JWT를 붙이고 다른 호스트에는 붙이지 않는다', () async {
    Future<Object?> headerFor(String method, String url) async {
      final dio = Dio()
        ..interceptors.add(AuthInterceptor(FakeTokenStorage('t')))
        ..interceptors.add(InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(Response(
            requestOptions: options,
            data: options.headers['Authorization'],
          )),
        ));
      return (await dio.request(url, options: Options(method: method))).data;
    }

    const host = 'https://workbook.devnoco.com';
    expect(await headerFor('GET', '$host/v8/favorites'), 'Bearer t');
    expect(await headerFor('DELETE', '$host/v8/favorites/550'), 'Bearer t');
    expect(await headerFor('POST', '$host/v8/auth/login'), isNull);
    expect(
      await headerFor('GET', 'https://api.themoviedb.org/v8/favorites'),
      isNull,
    );
  });
}
