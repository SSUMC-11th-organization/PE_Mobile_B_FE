import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/session/session_guard.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/button_width_demo_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_loader.dart';
import '../screens/movie_list_screen.dart';
import '../screens/my_page_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/profile_edit_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/start_screen.dart';
import '../theme/app_text_styles.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/favorite_detail_view_model.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/paged_movies_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/profile_edit_view_model.dart';
import '../view_models/session_ratings_store.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';

// 앱 전체의 화면 경로(라우트)를 한곳에서 관리하는 클래스
class AppRouter {
  AppRouter._(); // 인스턴스 생성 막기 — AppRouter.router로만 사용

  // 최상위 Navigator — ShellRoute 하위 라우트를 하단 탭 없이 전체 화면으로 띄울 때 사용
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  // 로그인 전에도 들어갈 수 있는 공개 화면
  static const publicPaths = {'/login', '/register', '/dev/buttons'};

  // 앱 전체에서 한 번만 생성 (main.dart의 State에서) — AuthViewModel이 바뀌면 redirect 재계산
  static GoRouter createRouter(AuthViewModel auth) => GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/start', // 앱 켰을 때 제일 먼저 보여줄 경로 (세션 확인 Splash)
    refreshListenable: auth,
    redirect: (context, state) => redirectFor(auth.status, state.uri.path),
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) => const StartScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const SignUpScreen(),
      ),
      // 개발용 버튼 데모 화면 (ShellRoute 밖)
      GoRoute(
        path: '/dev/buttons',
        builder: (context, state) => const ButtonWidthDemoScreen(),
      ),
      // 하단 NavigationBar가 있는 탭 화면들 — MainScreen이 공통 껍데기
      ShellRoute(
        builder: (context, state, child) => MainScreen(
          currentIndex: indexFromLocation(state.uri.path),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/home',
            // 홈 진입 시 ViewModel을 만들고 바로 한 번만 로드 (create는 build마다 다시 불리지 않음)
            // lazy: false — 홈 UI가 아직 ViewModel을 읽지 않아도 진입 즉시 생성되도록
            builder: (context, state) => ChangeNotifierProvider(
              lazy: false,
              create: (context) =>
                  MovieHomeViewModel(context.read<TmdbMovieService>())
                    ..loadPopular(),
              child: const HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/movies',
            // 목록 탭 진입 시 ViewModel 생성 — 첫 page 요청은 화면이 저장된 장르를 읽은 뒤 한 번 시작
            builder: (context, state) =>
                ChangeNotifierProvider<PagedMoviesViewModel>(
              create: (context) => PagedMoviesViewModel(
                tmdbApi: context.read<TmdbMovieService>(),
              ),
              child: const MovieListScreen(),
            ),
          ),
          GoRoute(
            path: '/my',
            builder: (context, state) => const MyPageScreen(),
            routes: [
              // 프로필 수정 — root Navigator에 띄움 → 하단 NavigationBar 없이 표시, pop하면 마이 탭으로
              GoRoute(
                path: 'profile/edit',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) =>
                    ChangeNotifierProvider<ProfileEditViewModel>(
                  create: (context) => ProfileEditViewModel(
                    context.read<MemberApiService>(),
                    context.read<AuthViewModel>(),
                  ),
                  child: const ProfileEditScreen(),
                ),
              ),
              // 평점 목록은 root Navigator에 띄움 → 하단 NavigationBar 없이 표시
              GoRoute(
                path: 'ratings',
                parentNavigatorKey: rootNavigatorKey,
                // 이번 세션 평점 + (학습용 memberId를 알 때만) 공개 조회 결과
                builder: (context, state) =>
                    ChangeNotifierProvider<MyRatingsViewModel>(
                  create: (context) => MyRatingsViewModel(
                    context.read<RatingApiService>(),
                    context.read<TmdbMovieService>(),
                    context.read<SessionRatingsStore>(),
                    context.read<AuthViewModel>(),
                    context.read<LearningMemberSession>().memberId,
                  )..load(),
                  child: const MyRatingsScreen(),
                ),
              ),
              // 내 즐겨찾기 — root Navigator에 띄움 → 하단 NavigationBar 없이 표시
              // 내 정보(email)가 준비되고 SessionGuard의 현재 세션과 일치할 때만 ViewModel 생성
              // ValueKey(email:generation) → 계정/세션이 바뀌면 이전 목록을 버리고 새로 만듦
              GoRoute(
                path: 'favorites',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final member = context.watch<AuthViewModel>().member;
                  final guard = context.read<SessionGuard>();
                  if (member == null || guard.accountId != member.email) {
                    return const _SessionWaitScreen(title: '내 즐겨찾기');
                  }
                  return ChangeNotifierProvider<FavoritesViewModel>(
                    key: ValueKey('${member.email}:${guard.generation}'),
                    create: (context) => FavoritesViewModel(
                      favoriteApi: context.read<FavoriteApiService>(),
                      tmdbApi: context.read<TmdbMovieService>(),
                      sessionGuard: guard,
                      accountId: member.email,
                    ),
                    child: const FavoritesScreen(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      // 상세 화면은 ShellRoute 밖 → 하단 NavigationBar 없이 전체 화면으로 표시
      GoRoute(
        path: '/movies/:movieId',
        // pathParameters는 String이라 int로 파싱. 숫자가 아니면 null → 상세 화면에서 안내 표시
        // extra = 카드에서 넘긴 TmdbMovieDto. URL 직접 진입 등으로 없으면 null
        // extra의 id가 경로 id와 같을 때만 initialMovie로 넘김 → 아니면 Loader가 TMDB에서 다시 조회
        // 즐겨찾기: 내 정보(email)가 준비되고 SessionGuard의 현재 세션과 일치할 때만
        // FavoriteDetailViewModel을 ValueKey(email:generation)와 함께 제공 → 계정/세션이 바뀌면 새로 생성
        builder: (context, state) {
          final movieId = int.tryParse(state.pathParameters['movieId'] ?? '');
          final extra = state.extra;
          final loader = MovieDetailLoader(
            movieId: movieId,
            initialMovie:
                extra is TmdbMovieDto && extra.id == movieId ? extra : null,
          );
          // 숫자가 아닌 경로 → Loader가 "찾을 수 없음"만 표시 (즐겨찾기 없음)
          if (movieId == null) return loader;

          final member = context.watch<AuthViewModel>().member;
          final guard = context.read<SessionGuard>();
          if (member == null || guard.accountId != member.email) {
            return const _SessionWaitScreen(title: '영화 상세');
          }
          return ChangeNotifierProvider<FavoriteDetailViewModel>(
            key: ValueKey('${member.email}:${guard.generation}'),
            create: (context) => FavoriteDetailViewModel(
              movieId: movieId,
              favoriteApi: context.read<FavoriteApiService>(),
              sessionGuard: guard,
              accountId: member.email,
            ),
            child: loader,
          );
        },
      ),
    ],
  );

  // 인증 상태별 이동 규칙 — null이면 요청한 경로 그대로
  // - initializing/retryRequired: Splash(/start)에 머무름
  // - signedOut/authenticating: /login과 공개 화면만 허용
  // - signedIn: /start·/login에 있으면 /home으로 (그 외 경로는 그대로)
  static String? redirectFor(AuthStatus status, String path) {
    switch (status) {
      case AuthStatus.initializing:
      case AuthStatus.retryRequired:
        return path == '/start' ? null : '/start';
      case AuthStatus.signedOut:
      case AuthStatus.authenticating:
        return publicPaths.contains(path) ? null : '/login';
      case AuthStatus.signedIn:
        return path == '/start' || path == '/login' ? '/home' : null;
    }
  }

  // 현재 경로로 선택할 탭 번호를 계산 (0: 홈, 1: 영화, 2: 마이)
  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }
}

// 상세·내 즐겨찾기 진입 시 내 정보(email)가 아직 없을 때의 대기 화면
// URL로 바로 들어오면 MainScreen을 거치지 않아 member가 비어 있을 수 있음 → 한 번 조회
// (이미 있거나 조회 중이면 loadMember는 아무것도 하지 않음)
class _SessionWaitScreen extends StatefulWidget {
  const _SessionWaitScreen({required this.title});

  final String title;

  @override
  State<_SessionWaitScreen> createState() => _SessionWaitScreenState();
}

class _SessionWaitScreenState extends State<_SessionWaitScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthViewModel>().loadMember();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final failed = auth.memberLoadStatus == MemberLoadStatus.error;
    return Scaffold(
      appBar: CommonAppBar(
        title: widget.title,
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
      body: Center(
        child: failed
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      auth.memberErrorMessage ?? '내 정보를 불러오지 못했습니다.',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    MovieLogButton(label: '다시 시도', onPressed: auth.loadMember),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
