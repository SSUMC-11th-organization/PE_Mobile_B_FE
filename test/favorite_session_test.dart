import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/favorites_view_model.dart';
import 'package:movielog/view_models/load_phase.dart';

// 응답을 붙잡아 두는 가짜 즐겨찾기 API (네트워크 없음)
class FakeFavoriteApi implements FavoriteApiService {
  final checks = <Completer<FavoriteCheckDto>>[];
  final lists = <Completer<List<FavoriteResponseDto>>>[];

  @override
  Future<FavoriteCheckDto> checkFavorite({required int movieId}) {
    final completer = Completer<FavoriteCheckDto>();
    checks.add(completer);
    return completer.future;
  }

  @override
  Future<List<FavoriteResponseDto>> fetchMyFavorites() {
    final completer = Completer<List<FavoriteResponseDto>>();
    lists.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// 영화 정보 보충은 바로 빈 결과 (이 테스트의 관심사는 세션 전환)
class FakeTmdbForFavorites implements TmdbMovieService {
  @override
  Future<Map<int, TmdbMovieDto>> fetchMovieDetails(
    List<int> movieIds, {
    int concurrency = 5,
  }) async =>
      const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('(d) 계정이 바뀐 뒤 늦게 도착한 이전 계정 응답은 즐겨찾기 ViewModel에 반영되지 않는다', () async {
    final guard = SessionGuard()..startSession('a@example.com');
    final api = FakeFavoriteApi();

    // 계정 A의 상세 버튼·내 즐겨찾기 ViewModel이 요청을 보낸 상태
    final detailA = FavoriteDetailViewModel(
      movieId: 550,
      favoriteApi: api,
      sessionGuard: guard,
      accountId: 'a@example.com',
    );
    final listA = FavoritesViewModel(
      favoriteApi: api,
      tmdbApi: FakeTmdbForFavorites(),
      sessionGuard: guard,
      accountId: 'a@example.com',
    );
    final detailLoad = detailA.load();
    final listLoad = listA.refresh();

    // 로그아웃 → 계정 B 로그인 (AuthSessionBridge가 하는 일)
    guard
      ..invalidate()
      ..startSession('b@example.com');

    // 계정 A의 응답이 늦게 도착
    api.checks[0].complete(
      const FavoriteCheckDto(movieId: 550, isFavorite: true),
    );
    api.lists[0].complete([
      FavoriteResponseDto(
        favoriteId: 1,
        movieId: 550,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    await detailLoad;
    await listLoad;

    expect(detailA.isFavorite, isFalse);
    expect(detailA.hasLoadedStatus, isFalse);
    expect(listA.items, isEmpty);
    expect(listA.phase, isNot(LoadPhase.ready));

    // 계정 B의 새 ViewModel은 B의 응답만 반영
    final detailB = FavoriteDetailViewModel(
      movieId: 550,
      favoriteApi: api,
      sessionGuard: guard,
      accountId: 'b@example.com',
    );
    final loadB = detailB.load();
    api.checks[1].complete(
      const FavoriteCheckDto(movieId: 550, isFavorite: false),
    );
    await loadB;
    expect(detailB.hasLoadedStatus, isTrue);
    expect(detailB.isFavorite, isFalse);

    detailA.dispose();
    listA.dispose();
    detailB.dispose();
  });
}
