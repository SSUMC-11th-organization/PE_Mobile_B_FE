import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/services/tmdb_movie_service.dart';
import '../screens/home_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/movie_list_screen.dart';
import '../screens/my_page_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/start_screen.dart';
import '../view_models/movie_home_view_model.dart';

// 앱 전체의 화면 경로(라우트)를 한곳에서 관리하는 클래스
class AppRouter {
  AppRouter._(); // 인스턴스 생성 막기 — AppRouter.router로만 사용

  static final GoRouter router = GoRouter(
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
            builder: (context, state) => const MovieListScreen(),
          ),
          GoRoute(
            path: '/my',
            builder: (context, state) => const MyPageScreen(),
          ),
        ],
      ),
      // 상세 화면은 ShellRoute 밖 → 하단 NavigationBar 없이 전체 화면으로 표시
      GoRoute(
        path: '/movies/:movieId',
        // pathParameters는 String이라 int로 파싱. 숫자가 아니면 null → 상세 화면에서 안내 표시
        builder: (context, state) => MovieDetailScreen(
          movieId: int.tryParse(state.pathParameters['movieId'] ?? ''),
        ),
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
