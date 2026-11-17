import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/main.dart';
import 'package:movielog/screens/login_screen.dart';
import 'package:movielog/screens/movie_detail_screen.dart';
import 'package:movielog/screens/sign_up_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/widgets/main_screen.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/rating_dialog.dart';
import 'package:provider/provider.dart';

import 'support/fakes.dart';

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

/// 읽기가 끝나지 않는 저장소: 세션 확인 중(initializing) 화면을 검증합니다.
class _HangingTokenStorage implements TokenStorage {
  final _never = Completer<String?>();

  @override
  Future<String?> readAccessToken() => _never.future;

  @override
  Future<void> saveAccessToken(String token) async {}

  @override
  Future<void> deleteAccessToken() async {}
}

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: '.env');
  });

  testWidgets('세션 확인 중에는 스플래시만 보이고 로그인 화면이 번쩍이지 않는다', (tester) async {
    await tester.pumpWidget(
      MovieLogApp(
        tokenStorage: _HangingTokenStorage(),
        tmdbMovieService: FakeTmdb(),
        authApiService: FakeAuthApi(),
        memberApiService: FakeMemberApi(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('영화의 순간을\n기록하세요'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('토큰이 없으면 스플래시 → 로그인, 가입 성공 → 자동 로그인 → 홈', (tester) async {
    await tester.pumpWidget(
      MovieLogApp(
        tokenStorage: FakeTokenStorage(),
        signUpService: _FakeSignUpService(),
        tmdbMovieService: FakeTmdb(),
        authApiService: FakeAuthApi(),
        memberApiService: FakeMemberApi(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.tap(find.text('회원가입'));
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
    expect(find.byType(MainScreen), findsOneWidget); // Router가 /home으로 이동
  });

  testWidgets('저장된 토큰이 GET me로 검증되면 바로 홈으로 간다', (tester) async {
    await tester.pumpWidget(
      MovieLogApp(
        tokenStorage: FakeTokenStorage('saved-token'),
        tmdbMovieService: FakeTmdb(),
        authApiService: FakeAuthApi(),
        memberApiService: FakeMemberApi(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('movie detail opens rating dialog with comment field', (
    tester,
  ) async {
    final movie = fakeMovie();
    final auth = AuthViewModel(FakeAuthApi(), FakeMemberApi(), FakeTokenStorage());
    final ratingApi = FakeRatingApi();
    final myRatings = MyRatingsViewModel(ratingApi, FakeTmdb(), auth);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ChangeNotifierProvider(
          create: (_) => MovieDetailViewModel(ratingApi, auth, myRatings, movie),
          child: MovieDetailScreen(movieId: 42, movie: movie),
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
