import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jay/data/models/tmdb_movie_dto.dart';
import 'package:jay/data/services/member_api_service.dart';
import 'package:jay/data/services/sign_up_service.dart';
import 'package:jay/data/services/rating_api_service.dart';
import 'package:jay/data/services/tmdb_movie_service.dart';
import 'package:jay/screens/edit_profile_screen.dart';
import 'package:jay/screens/login_screen.dart';
import 'package:jay/screens/main_screen.dart';
import 'package:jay/screens/movie_detail_loader.dart';
import 'package:jay/screens/my_ratings_screen.dart';
import 'package:jay/screens/profile_screen.dart';
import 'package:jay/screens/signup_screen.dart';
import 'package:jay/view_models/auth_view_model.dart';
import 'package:jay/view_models/edit_profile_view_model.dart';
import 'package:jay/view_models/learning_member_session.dart';
import 'package:jay/view_models/session_rating_store.dart';
import 'package:jay/view_models/movie_home_view_model.dart';
import 'package:jay/view_models/movie_list_view_model.dart';
import 'package:jay/view_models/my_rating_view_model.dart';
import 'package:jay/view_models/signup_view_model.dart';
import 'package:jay/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

import '../screens/home_screen.dart';
import '../screens/movie_list_screen.dart';
import '../screens/start_screen.dart';

String? authRedirect(AuthStatus status, String location) {
  const publicPaths = {'/login', '/register'};
  final atStart = location == '/start';
  final atPublic = publicPaths.contains(location);

  return switch (status) {
    AuthStatus.initializing ||
    AuthStatus.retryRequired => atStart ? null : '/start',
    AuthStatus.signedOut ||
    AuthStatus.authenticating => atPublic ? null : '/login',
    AuthStatus.signedIn => (atStart || atPublic) ? '/home' : null,
  };
}

class AppRouter {
  AppRouter._();

  // root Navigator를 가리키는 키를 클래스에서 한 번만 선언한다
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter createRouter(AuthViewModel authViewModel) {
    return GoRouter(
      initialLocation: '/start',
      navigatorKey: rootNavigatorKey,
      refreshListenable: authViewModel,
      redirect: (context, state) {
        return authRedirect(authViewModel.status, state.uri.path);
      },
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) {
            final auth = context.watch<AuthViewModel>();
            return StartScreen(
              message: auth.message,
              onRetry: auth.status == AuthStatus.retryRequired
                  ? auth.restoreSession
                  : null,
            );
          },
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => ChangeNotifierProvider<SignupViewModel>(
            create: (context) => SignupViewModel(context.read<SignUpService>()),
            child: const SignUpScreen(),
          ),
        ),
        ShellRoute(
          builder: (context, state, child) {
            return MainScreen(
              currentIndex: indexFromLocation(state.uri.path),
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) =>
                  ChangeNotifierProvider<MovieHomeViewModel>(
                    create: (context) =>
                        MovieHomeViewModel(context.read<TmdbMovieService>())
                          ..loadPopular(),
                    child: const HomeScreen(),
                  ),
            ),

            GoRoute(
              path: '/movies',
              builder: (context, state) =>
                  ChangeNotifierProvider<MovieListViewModel>(
                    create: (context) =>
                        MovieListViewModel(context.read<TmdbMovieService>())
                          ..loadInitial(),
                    child: const MovieListScreen(),
                  ),
            ),

            GoRoute(
              path: '/my',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'ratings', // 최종 경로: /my/ratings
                  // root Navigator 위에 표시해 하단 NavigationBar를 가린다
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) {
                    final auth = context.read<AuthViewModel>();
                    // v7 로그인·내 정보에는 memberId가 없습니다.
                    // 이 앱에서 가입한 계정과 같은 email로 로그인했을 때만 공개 목록을 조회하고,
                    // 아니면 현재 세션에서 등록한 평점만 보여줍니다.
                    final id = context
                        .read<LearningMemberSession>()
                        .memberIdFor(auth.member?.email);
                    return ChangeNotifierProvider<MyRatingsViewModel>(
                      create: (context) => MyRatingsViewModel(
                        context.read<RatingApiService>(),
                        context.read<TmdbMovieService>(),
                        auth,
                        context.read<SessionRatingStore>(),
                        id,
                      )..load(),
                      child: const MyRatingsScreen(),
                    );
                  },
                ),
                GoRoute(
                  path: 'profile/edit', // 최종 경로: /my/profile/edit
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) {
                    final auth = context.watch<AuthViewModel>();
                    if (auth.member == null) {
                      return Scaffold(
                        appBar: AppBar(
                          centerTitle: true,
                          title: const Text('프로필 수정'),
                        ),
                        body: Center(
                          child: auth.memberStatus == MemberLoadStatus.error
                              ? MovieLogButton(
                                  label: '다시 시도',
                                  width: 180,
                                  onPressed: () =>
                                      auth.loadMember(force: true),
                                )
                              : const CircularProgressIndicator(),
                        ),
                      );
                    }
                    return ChangeNotifierProvider<EditProfileViewModel>(
                      create: (context) => EditProfileViewModel(
                        context.read<MemberApiService>(),
                        auth,
                      ),
                      child: const EditProfileScreen(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        // 상세는 NavigationBar 없이 전체 화면으로 보여주기 위해 ShellRoute 밖에 둔다
        GoRoute(
          path: '/movies/:movieId',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['movieId'] ?? '');
            if (id == null || id < 1) {
              return const Scaffold(
                body: Center(child: Text('영화 ID가 올바르지 않습니다.')),
              );
            }
            final extra = state.extra;
            return MovieDetailLoader(
              movieId: id,
              initialMovie: extra is TmdbMovieDto && extra.id == id
                  ? extra
                  : null,
            );
          },
        ),
      ],
    );
  }

  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }
}
