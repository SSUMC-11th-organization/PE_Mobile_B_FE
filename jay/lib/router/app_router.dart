import 'package:go_router/go_router.dart';
import 'package:jay/data/models/tmdb_movie_dto.dart';
import 'package:jay/data/services/tmdb_movie_service.dart';
import 'package:jay/screens/main_screen.dart';
import 'package:jay/screens/profile_screen.dart';
import 'package:jay/screens/signup_screen.dart';
import 'package:jay/view_models/movie_home_view_model.dart';
import 'package:jay/view_models/movie_list_view_model.dart';
import 'package:provider/provider.dart';

import '../screens/home_screen.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/movie_list_screen.dart';
import '../screens/start_screen.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: (context, state) => const StartScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const SignUpScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainScreen(
            currentIndex: indexFromLocation(state.uri.path),
            child: child,
          );
        },
        routes: [
          // 화면별 ViewModel은 Route마다 생성하고, 화면을 벗어나면 dispose된다
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
          ),
        ],
      ),
      // 상세는 NavigationBar 없이 전체 화면으로 보여주기 위해 ShellRoute 밖에 둔다
      GoRoute(
        path: '/movies/:movieId',
        builder: (context, state) => MovieDetailScreen(
          movieId: int.parse(state.pathParameters['movieId']!),
          movie: state.extra as TmdbMovieDto?,
        ),
      ),
    ],
  );

  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }
}
