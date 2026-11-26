import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';
import 'package:movielog/main.dart';
import 'package:movielog/screens/movie_search_screen.dart';
import 'package:movielog/widgets/movie_card.dart';

import 'support/fakes.dart';

class _Tmdb extends FakeTmdb {
  @override
  Future<TmdbMovieDto> fetchMovieDetail(int movieId) async =>
      fakeMovie(id: movieId);

  @override
  Future<TmdbMoviePageDto> searchMovies({
    required int page,
    required String query,
  }) async =>
      TmdbMoviePageDto(
          page: 1, results: [fakeMovie()], totalPages: 1, totalResults: 1);
}

/// 해제하면 목록에서도 사라지는 가짜 서버.
class _Favorites extends FakeFavoriteApi {
  @override
  Future<void> deleteFavorite({required int movieId}) async {
    await super.deleteFavorite(movieId: movieId);
    favoriteIds.remove(movieId);
  }
}

void main() {
  setUpAll(() async => dotenv.load(fileName: '.env'));

  Future<void> pumpApp(WidgetTester tester, _Favorites favorites) async {
    await tester.pumpWidget(MovieLogApp(
      tokenStorage: FakeTokenStorage('saved-token'),
      tmdbMovieService: _Tmdb(),
      authApiService: FakeAuthApi(),
      memberApiService: FakeMemberApi(),
      favoriteApiService: favorites,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('마이 → 내 즐겨찾기 → 상세 해제 → 뒤로가기하면 목록이 갱신된다', (tester) async {
    final favorites = _Favorites()
      ..favoriteIds = [42]
      ..serverFavorite = true;
    await pumpApp(tester, favorites);

    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('내 즐겨찾기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 즐겨찾기'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byType(MovieCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('즐겨찾기 해제'));
    await tester.pumpAndSettle();
    expect(find.text('즐겨찾기에서 삭제했습니다.'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('아직 즐겨찾기한 영화가 없습니다.'), findsOneWidget);
  });

  testWidgets('영화 → 검색 아이콘 → 검색 → 상세로 이동한다', (tester) async {
    await pumpApp(tester, _Favorites());

    await tester.tap(find.text('영화'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('영화 검색'));
    await tester.pumpAndSettle();
    expect(find.byType(MovieSearchScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.enterText(find.byType(TextField), '  ');
    await tester.tap(find.byTooltip('검색'));
    await tester.pump();
    expect(find.text('검색어를 입력해 주세요.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '테스트');
    await tester.tap(find.byTooltip('검색'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MovieCard));
    await tester.pumpAndSettle();
    expect(find.byTooltip('즐겨찾기 등록'), findsOneWidget);
  });
}
