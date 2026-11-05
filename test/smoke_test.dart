import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/main.dart';
import 'package:movielog/screens/home_screen.dart';
import 'package:movielog/screens/movie_detail_screen.dart';
import 'package:movielog/screens/sign_up_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/widgets/rating_dialog.dart';

void main() {
  setUpAll(() async {
    // MovieHomeViewModel이 TmdbConfig.accessToken(dotenv)을 읽으므로
    // main()과 마찬가지로 load를 먼저 끝내야 한다. 실제 네트워크 성공 여부는
    // 이 테스트의 관심사가 아니라서 토큰 값 자체는 비어 있어도 된다.
    await dotenv.load(fileName: '.env');
  });

  testWidgets('start -> register -> home flow has no back stack', (
    tester,
  ) async {
    await tester.pumpWidget(const MovieLogApp());
    await tester.pumpAndSettle();
    expect(find.text('영화의 순간을\n기록하세요'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '무비러버');
    await tester.enterText(find.byType(TextFormField).at(1), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password1');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    final context = tester.element(find.byType(HomeScreen));
    expect(Navigator.of(context).canPop(), isFalse);
  });

  testWidgets('movie detail screen renders a given movie and opens rating dialog', (
    tester,
  ) async {
    const movie = TmdbMovieDto(
      id: 42,
      title: '테스트 영화',
      overview: '줄거리입니다.',
      posterPath: null,
      backdropPath: null,
      releaseDate: '2024-05-01',
      genreIds: [18],
      voteAverage: 8.4,
      popularity: 120.5,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MovieDetailScreen(movieId: 42, movie: movie),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('테스트 영화'), findsAtLeastNWidgets(1));
    expect(find.text('줄거리입니다.'), findsOneWidget);

    await tester.tap(find.text('평점 남기기'));
    await tester.pumpAndSettle();
    expect(find.byType(RatingDialog), findsOneWidget);
  });
}
