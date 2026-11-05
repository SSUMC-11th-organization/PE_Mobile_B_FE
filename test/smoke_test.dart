import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/main.dart';
import 'package:movielog/screens/home_screen.dart';
import 'package:movielog/screens/movie_detail_screen.dart';
import 'package:movielog/screens/sign_up_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/widgets/rating_dialog.dart';

class _FakeSmokeMemberCheckService implements MemberCheckService {
  @override
  Future<bool> checkNickname(String nickname) async => true;

  @override
  Future<bool> checkEmail(String email) async => true;
}

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: '.env');
  });

  testWidgets('start -> register -> home flow has no back stack', (
    tester,
  ) async {
    await tester.pumpWidget(
      MovieLogApp(
        memberCheckService: _FakeSmokeMemberCheckService(),
      ),
    );
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

    // 6주차 중복 확인 수행
    final checkButtons = find.text('중복 확인');
    expect(checkButtons, findsNWidgets(2));
    await tester.tap(checkButtons.at(0));
    await tester.pumpAndSettle();
    await tester.tap(checkButtons.at(1));
    await tester.pumpAndSettle();

    // 가입하기 버튼 탭
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    final context = tester.element(find.byType(HomeScreen));
    expect(Navigator.of(context).canPop(), isFalse);
  });

  testWidgets(
      'movie detail screen renders a given movie and opens rating dialog', (
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
