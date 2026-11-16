import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';

// 네트워크 없이 page 요청을 붙잡아 두었다가 테스트가 원하는 순서로 응답/실패시키는 가짜 TMDB 서비스
class _PendingPage {
  _PendingPage(this.page, this.genreId);

  final int page;
  final int? genreId;
  final completer = Completer<TmdbMoviePageDto>();
}

class FakeTmdbMovieService implements TmdbMovieService {
  final requests = <_PendingPage>[];

  @override
  Future<TmdbMoviePageDto> fetchMoviePage({required int page, int? genreId}) {
    final pending = _PendingPage(page, genreId);
    requests.add(pending);
    return pending.completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TmdbMovieDto movie(int id) => TmdbMovieDto(
      id: id,
      title: '영화 $id',
      originalTitle: 'Movie $id',
      overview: '',
      posterPath: null,
      backdropPath: null,
      releaseDate: '',
      voteAverage: 0,
      voteCount: 0,
      popularity: 0,
      genreIds: const [],
      adult: false,
    );

TmdbMoviePageDto pageOf(int page, List<int> ids, {int totalPages = 3}) =>
    TmdbMoviePageDto(
      page: page,
      results: [for (final id in ids) movie(id)],
      totalPages: totalPages,
      totalResults: totalPages * 20,
    );

List<int> idsOf(PagedMoviesViewModel vm) => [for (final m in vm.movies) m.id];

void main() {
  late FakeTmdbMovieService api;
  late PagedMoviesViewModel vm;

  setUp(() {
    api = FakeTmdbMovieService();
    vm = PagedMoviesViewModel(tmdbApi: api);
  });

  tearDown(() => vm.dispose());

  test('(a) 장르를 바꾼 뒤 늦게 도착한 이전 장르 응답은 반영되지 않는다', () async {
    final oldRequest = vm.loadInitial(genreId: 1); // 느린 이전 요청
    final newRequest = vm.loadInitial(genreId: 2); // 장르 변경 → 전부 초기화

    api.requests[1].completer.complete(pageOf(1, [20, 21]));
    await newRequest;
    api.requests[0].completer.complete(pageOf(1, [10, 11])); // 늦게 도착
    await oldRequest;

    expect(vm.condition.genreId, 2);
    expect(vm.phase, LoadPhase.ready);
    expect(idsOf(vm), [20, 21]);
    expect(vm.nextPage, 2);
  });

  test('(b) 다음 page가 실패하면 nextPage가 그대로라 같은 page를 다시 요청한다', () async {
    final first = vm.loadInitial();
    api.requests[0].completer.complete(pageOf(1, [1, 2]));
    await first;

    final failed = vm.loadNextPage();
    expect(api.requests[1].page, 2);
    expect(vm.isLoadingMore, isTrue);
    api.requests[1].completer.completeError(Exception('network'));
    await failed;

    expect(vm.nextPage, 2); // 올라가지 않음
    expect(vm.loadMoreError, isNotNull);
    expect(vm.isLoadingMore, isFalse);
    expect(idsOf(vm), [1, 2]); // 기존 카드 유지

    final retry = vm.loadNextPage();
    expect(api.requests[2].page, 2); // 같은 page 재시도
    api.requests[2].completer.complete(pageOf(2, [3, 4]));
    await retry;

    expect(vm.nextPage, 3);
    expect(vm.loadMoreError, isNull);
    expect(idsOf(vm), [1, 2, 3, 4]);
  });

  test('(c) 다음 page에 이미 가진 movieId가 오면 중복 카드를 제외한다', () async {
    final first = vm.loadInitial();
    api.requests[0].completer.complete(pageOf(1, [1, 2, 3]));
    await first;

    final next = vm.loadNextPage();
    api.requests[1].completer.complete(pageOf(2, [3, 2, 4, 4, 5]));
    await next;

    expect(idsOf(vm), [1, 2, 3, 4, 5]);
  });
}
