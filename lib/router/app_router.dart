import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/button_width_demo_screen.dart';
import '../screens/home_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_loader.dart';
import '../screens/movie_list_screen.dart';
import '../screens/my_page_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/start_screen.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';

// 앱 전체의 화면 경로(라우트)를 한곳에서 관리하는 클래스
class AppRouter {
  AppRouter._(); // 인스턴스 생성 막기 — AppRouter.router로만 사용

  // 최상위 Navigator — ShellRoute 하위 라우트를 하단 탭 없이 전체 화면으로 띄울 때 사용
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/start', // 앱 켰을 때 제일 먼저 보여줄 경로
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) => const StartScreen(),
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
            // 목록 탭 진입 시 ViewModel 생성 + 장르/영화 첫 로드 (한 번만)
            builder: (context, state) => ChangeNotifierProvider(
              create: (context) =>
                  MovieListViewModel(context.read<TmdbMovieService>())
                    ..loadInitial(),
              child: const MovieListScreen(),
            ),
          ),
          GoRoute(
            path: '/my',
            builder: (context, state) => const MyPageScreen(),
            routes: [
              // 평점 목록은 root Navigator에 띄움 → 하단 NavigationBar 없이 표시
              GoRoute(
                path: 'ratings',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  // 회원가입으로 받은 학습용 memberId — 아직 가입 전이면 안내만 표시
                  final memberId =
                      context.read<LearningMemberSession>().memberId;
                  if (memberId == null) {
                    return Scaffold(
                      appBar: AppBar(
                        centerTitle: true,
                        title: const Text('내가 등록한 평점'),
                        leading: const BackButton(),
                      ),
                      body: const Center(
                        child: Text('학습용 회원가입이 필요합니다.'),
                      ),
                    );
                  }
                  return ChangeNotifierProvider<MyRatingsViewModel>(
                    create: (context) => MyRatingsViewModel(
                      context.read<RatingApiService>(),
                      context.read<TmdbMovieService>(),
                      memberId,
                    )..load(),
                    child: const MyRatingsScreen(),
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
        builder: (context, state) {
          final movieId = int.tryParse(state.pathParameters['movieId'] ?? '');
          final extra = state.extra;
          return MovieDetailLoader(
            movieId: movieId,
            initialMovie:
                extra is TmdbMovieDto && extra.id == movieId ? extra : null,
          );
        },
      ),
    ],
  );

  // 현재 경로로 선택할 탭 번호를 계산 (0: 홈, 1: 영화, 2: 마이)
  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }
}
