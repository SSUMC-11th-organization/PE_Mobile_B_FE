import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/session/session_guard.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/edit_profile/edit_profile_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/main/main_screen.dart';
import '../screens/movie_detail/movie_detail_loader.dart';
import '../screens/movie_list/movie_list_screen.dart';
import '../screens/my_ratings/my_ratings_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/sign_up/sign_up_screen.dart';
import '../screens/start/start_screen.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../view_models/favorite_detail_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/session_ratings.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/movielog_button.dart';

/// 인증 상태와 현재 위치만 보고 "어디로 보낼지"를 정하는 규칙. 이동이 필요 없으면 null.
/// 상태만 읽고 판단하며, API 호출 같은 비동기 작업은 하지 않음
String? authRedirect(AuthStatus status, String location) {
  const publicPaths = {'/login', '/register'};
  final atStart = location == '/start';
  final atPublic = publicPaths.contains(location);

  return switch (status) {
    // 토큰 확인 중 또는 확인 실패(재시도 버튼): 스플래시 화면 유지
    AuthStatus.initializing ||
    AuthStatus.retryRequired => atStart ? null : '/start',
    // 로그아웃 또는 로그인 요청 중: 공개 화면만 허용
    AuthStatus.signedOut ||
    AuthStatus.authenticating => atPublic ? null : '/login',
    // 로그인됨: 스플래시와 로그인·회원가입 화면은 홈으로 보냄
    AuthStatus.signedIn => (atStart || atPublic) ? '/home' : null,
  };
}

class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  /// 8주차: static final router → AuthViewModel을 받는 createRouter()로 변경.
  /// redirect는 이동할 때만 호출되므로 refreshListenable로 인증 상태 변경에도 다시 검사하게 함
  static GoRouter createRouter(AuthViewModel authViewModel) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/start',
      refreshListenable: authViewModel,
      redirect: (context, state) {
        return authRedirect(authViewModel.status, state.uri.path);
      },
      routes: [
        GoRoute(
          path: '/start', // 스플래시: 토큰 확인 중 / 확인 실패 시 재시도
          builder: (context, state) {
            final auth = context.watch<AuthViewModel>();
            return SplashScreen(
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
          builder: (context, state) => ChangeNotifierProvider<SignUpViewModel>(
            create: (context) => SignUpViewModel(context.read<SignUpService>()),
            child: const SignUpScreen(),
          ),
        ),
        ShellRoute(
          builder: (context, state, child) => MainScreen(
            currentIndex: _indexFromLocation(state.uri.path),
            child: child,
          ),
          routes: [
            // 화면별 ViewModel은 각 Route 안에서 생성하고, 생성 직후 ..load로 첫 요청
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
                  path: 'profile/edit', // 최종 경로 /my/profile/edit
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final auth = context.watch<AuthViewModel>();
                    // 주소로 바로 들어와 내 정보가 아직 없으면 로딩 또는 재시도만 표시
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
                                  onPressed: () => auth.loadMember(force: true),
                                )
                              : const CircularProgressIndicator(),
                        ),
                      );
                    }
                    // 이 화면에서만 쓰는 ViewModel이라 Route 안에서 생성
                    return ChangeNotifierProvider<EditProfileViewModel>(
                      create: (context) => EditProfileViewModel(
                        context.read<MemberApiService>(),
                        auth,
                      ),
                      child: const EditProfileScreen(),
                    );
                  },
                ),
                GoRoute(
                  path: 'ratings', // 최종 경로 /my/ratings
                  // root Navigator 위에 띄워 ShellRoute의 하단 NavigationBar를 가림
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    // 8주차: 학습용 memberId 대신 토큰 기반 Service와 이번 세션의 평점 목록을 사용
                    return ChangeNotifierProvider<MyRatingsViewModel>(
                      create: (context) => MyRatingsViewModel(
                        context.read<RatingApiService>(),
                        context.read<TmdbMovieService>(),
                        context.read<AuthViewModel>(),
                        context.read<SessionRatings>(),
                      )..load(),
                      child: const MyRatingsScreen(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/movies/:movieId',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            // movieId는 URL 식별자, 화면에 넘길 DTO는 extra에서 꺼냄 (없으면 Loader가 TMDB에서 재조회)
            final id = int.tryParse(state.pathParameters['movieId'] ?? '');
            if (id == null || id < 1) {
              return const Scaffold(
                body: Center(child: Text('영화 ID가 올바르지 않습니다.')),
              );
            }
            final extra = state.extra;
            final member = context.watch<AuthViewModel>().member;
            final guard = context.read<SessionGuard>();

            // 내 정보가 준비되고 현재 세션과 일치할 때까지 로딩 표시
            if (member == null || guard.accountId != member.email) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // 9주차: 즐겨찾기 버튼 상태를 상세 Route에서 제공.
            // 기존 MovieDetailLoader(영화 조회 + 평점 ViewModel)는 그대로 child로 둠
            return ChangeNotifierProvider<FavoriteDetailViewModel>(
              // 계정이나 세션이 바뀌면 key 값이 달라져 이전 사용자의 ViewModel을 버리고 새로 만듦
              key: ValueKey('${member.email}:${guard.generation}'),
              create: (context) => FavoriteDetailViewModel(
                movieId: id,
                favoriteApi: context.read<FavoriteApiService>(),
                sessionGuard: guard,
                accountId: member.email,
              ),
              child: MovieDetailLoader(
                movieId: id,
                initialMovie: extra is TmdbMovieDto && extra.id == id
                    ? extra
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }

  static int _indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }
}
