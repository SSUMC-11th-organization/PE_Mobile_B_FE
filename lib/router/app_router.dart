import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/session/session_guard.dart';
import '../data/models/member_info.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/member_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/movie_detail_loader.dart';
import '../screens/movie_list_screen.dart';
import '../screens/movie_search_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/start_screen.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../view_models/favorite_detail_view_model.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/paged_movies_view_model.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/main_screen.dart';
import '../widgets/movielog_button.dart';

/// 인증 상태 → 이동 규칙. 상태만 읽고 판단하며 비동기 작업은 하지 않습니다.
String? authRedirect(AuthStatus status, String location) {
  const publicPaths = {'/login', '/register'};
  final atStart = location == '/start';
  final atPublic = publicPaths.contains(location);

  return switch (status) {
    // 토큰 확인 중 또는 확인 실패(재시도 버튼): 스플래시 유지
    AuthStatus.initializing ||
    AuthStatus.retryRequired =>
      atStart ? null : '/start',
    // 로그아웃 또는 로그인 요청 중: 공개 화면만 허용
    AuthStatus.signedOut ||
    AuthStatus.authenticating =>
      atPublic ? null : '/login',
    // 로그인됨: 스플래시와 로그인·회원가입 화면은 홈으로
    AuthStatus.signedIn => (atStart || atPublic) ? '/home' : null,
  };
}

class AppRouter {
  AppRouter._();

  /// root Navigator를 가리키는 키 (GoRouter 전체 및 ShellRoute 바깥 라우트에서 공유)
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter createRouter(AuthViewModel authViewModel) {
    return GoRouter(
      initialLocation: '/start',
      navigatorKey: rootNavigatorKey,
      refreshListenable: authViewModel, // 인증 상태가 바뀌면 redirect를 다시 실행합니다.
      redirect: (context, state) =>
          authRedirect(authViewModel.status, state.uri.path),
      routes: [
        GoRoute(
          path: '/start', // 스플래시: 토큰 확인 중 / 확인 실패 시 재시도
          parentNavigatorKey: rootNavigatorKey,
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
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => ChangeNotifierProvider<SignUpViewModel>(
            create: (context) => SignUpViewModel(
              context.read<SignUpService>(),
            ),
            child: const SignUpScreen(),
          ),
        ),
        // 정적인 search를 동적인 :movieId보다 먼저 등록해야 합니다.
        GoRoute(
          path: '/movies/search',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => ChangeNotifierProvider(
            create: (context) =>
                PagedMoviesViewModel(context.read<TmdbMovieService>()),
            child: const MovieSearchScreen(),
          ),
        ),
        GoRoute(
          path: '/movies/:movieId',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['movieId'] ?? '');
            if (id == null || id < 1) {
              return const Scaffold(
                body: Center(child: Text('영화 ID가 올바르지 않습니다.')),
              );
            }
            final extra = state.extra;
            return _withMember('영화 상세', (context, member, guard) {
              return ChangeNotifierProvider(
                // 계정이나 세션이 바뀌면 새 ViewModel을 만듭니다.
                key: ValueKey('${member.email}:${guard.generation}'),
                create: (context) => FavoriteDetailViewModel(
                  movieId: id,
                  favoriteApi: context.read<FavoriteApiService>(),
                  sessionGuard: guard,
                  accountId: member.email,
                  onSessionExpired: context.read<AuthViewModel>().expireSession,
                ),
                child: MovieDetailLoader(
                  movieId: id,
                  initialMovie:
                      extra is TmdbMovieDto && extra.id == id ? extra : null,
                ),
              );
            });
          },
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
              builder: (context, state) => ChangeNotifierProvider(
                create: (context) =>
                    MovieHomeViewModel(context.read<TmdbMovieService>())
                      ..loadPopular(),
                child: const HomeScreen(),
              ),
            ),
            GoRoute(
              path: '/movies',
              builder: (context, state) => ChangeNotifierProvider(
                create: (context) =>
                    PagedMoviesViewModel(context.read<TmdbMovieService>())
                      ..loadGenres()
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
                  // root Navigator 위에 push하여 하단 NavigationBar를 가림
                  parentNavigatorKey: rootNavigatorKey,
                  // MyRatingsViewModel은 앱 전역(MultiProvider)에 있습니다.
                  builder: (context, state) => const MyRatingsScreen(),
                ),
                GoRoute(
                  path: 'favorites', // 최종 경로: /my/favorites
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) =>
                      _withMember('내 즐겨찾기', (context, member, guard) {
                    return ChangeNotifierProvider(
                      key: ValueKey('${member.email}:${guard.generation}'),
                      create: (context) => FavoritesViewModel(
                        favoriteApi: context.read<FavoriteApiService>(),
                        tmdbApi: context.read<TmdbMovieService>(),
                        sessionGuard: guard,
                        accountId: member.email,
                        onSessionExpired:
                            context.read<AuthViewModel>().expireSession,
                      ),
                      child: const FavoritesScreen(),
                    );
                  }),
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
                                  onPressed: () => auth.loadMember(force: true),
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
      ],
    );
  }

  /// 내 정보가 준비되고 현재 세션과 일치할 때만 계정별 화면을 만듭니다.
  static Widget _withMember(
    String title,
    Widget Function(BuildContext, MemberInfo, SessionGuard) builder,
  ) {
    return Builder(
      builder: (context) {
        final auth = context.watch<AuthViewModel>();
        final member = auth.member;
        final guard = context.read<SessionGuard>();
        if (member != null && guard.accountId == member.email) {
          return builder(context, member, guard);
        }
        // MainScreen을 거치지 않고 들어온 경우를 위해 여기서도 재시도를 제공합니다.
        return Scaffold(
          appBar: AppBar(title: Text(title), centerTitle: true),
          body: Center(
            child: auth.memberStatus == MemberLoadStatus.error
                ? MovieLogButton(
                    label: '내 정보 다시 조회',
                    onPressed: () => auth.loadMember(force: true),
                  )
                : const CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }
}
