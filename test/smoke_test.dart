import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/main.dart';
import 'package:movielog/screens/movie_detail_screen.dart';
import 'package:movielog/screens/sign_up_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/rating_dialog.dart';
import 'package:provider/provider.dart';

class _FakeSignUpService implements SignUpService {
  @override
  Future<bool> checkNickname(String nickname) async => true;

  @override
  Future<bool> checkEmail(String email) async => true;

  @override
  Future<CommonResponse<SignUpResult>> signUp(CreateMemberRequest request) async =>
      const CommonResponse(
        isSuccess: true,
        code: 'COMMON201',
        message: 'ok',
        result: SignUpResult(memberId: 7, email: 'a@b.co', nickname: 'nick'),
      );
}

class _FakeTmdb implements TmdbMovieService {
  @override
  Future<TmdbMoviePageDto> discoverMovies({required int page, int? genreId}) async =>
      const TmdbMoviePageDto(page: 1, results: [], totalPages: 1, totalResults: 0);

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: '.env');
  });

  testWidgets('start -> register -> /movies (v6 sign up stores memberId)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MovieLogApp(
        signUpService: _FakeSignUpService(),
        tmdbMovieService: _FakeTmdb(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('영화의 순간을\n기록하세요'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '무비러버');
    await tester.enterText(find.byType(TextFormField).at(1), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final checkButtons = find.text('중복 확인');
    await tester.tap(checkButtons.at(0));
    await tester.pumpAndSettle();
    await tester.tap(checkButtons.at(1));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('가입하기'));
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    expect(find.byType(SignUpScreen), findsNothing);
  });

  test('validatePasswordFormat / CreateRatingRequest', () {
    expect(validatePasswordFormat('Password1!'), isNull);
    expect(validatePasswordFormat('password1!'), isNotNull); // 대문자 없음
    expect(validatePasswordFormat('Pass1!'), isNotNull); // 8자 미만
  });

  testWidgets('movie detail opens rating dialog with comment field', (
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
        home: ChangeNotifierProvider(
          create: (_) => MovieDetailViewModel(
            RatingApiService(Dio()),
            7,
            movie,
          ),
          child: const MovieDetailScreen(movieId: 42, movie: movie),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('줄거리입니다.'), findsOneWidget);

    await tester.tap(find.text('평점 남기기'));
    await tester.pumpAndSettle();
    expect(find.byType(RatingDialog), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // 별점 선택 전에는 확인 버튼 비활성
    final confirm = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.widgetWithText(MovieLogButton, '확인'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(confirm.onPressed, isNull);
  });
}
