import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jay/data/models/tmdb_movie_dto.dart';
import 'package:jay/data/services/sign_up_service.dart';
import 'package:jay/data/services/rating_api_service.dart';
import 'package:jay/data/services/tmdb_movie_service.dart';
import 'package:jay/screens/main_screen.dart';
import 'package:jay/screens/movie_detail_loader.dart';
import 'package:jay/screens/my_ratings_screen.dart';
import 'package:jay/screens/profile_screen.dart';
import 'package:jay/screens/signup_screen.dart';
import 'package:jay/view_models/learning_member_session.dart';
import 'package:jay/view_models/movie_home_view_model.dart';
import 'package:jay/view_models/movie_list_view_model.dart';
import 'package:jay/view_models/my_rating_view_model.dart';
import 'package:jay/view_models/signup_view_model.dart';
import 'package:provider/provider.dart';

import '../screens/home_screen.dart';
import '../screens/movie_list_screen.dart';
import '../screens/start_screen.dart';

class AppRouter {
  AppRouter._();

  // root Navigator를 가리키는 키를 클래스에서 한 번만 선언한다
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    initialLocation: '/start',
    navigatorKey: rootNavigatorKey,
    routes: [
      GoRoute(path: '/start', builder: (context, state) => const StartScreen()),
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
            routes: [
              GoRoute(
                path: 'ratings', // 최종 경로: /my/ratings
                // root Navigator 위에 표시해 하단 NavigationBar를 가린다
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  // 7주차: 회원가입 결과로 저장한 학습용 memberId를 읽는다
                  final id = context.read<LearningMemberSession>().memberId;
                  if (id == null) {
                    return Scaffold(
                      appBar: AppBar(
                        centerTitle: true,
                        title: const Text('내가 등록한 평점'),
                      ),
                      body: const Center(child: Text('학습용 회원가입이 필요합니다.')),
                    );
                  }
                  return ChangeNotifierProvider<MyRatingsViewModel>(
                    create: (context) => MyRatingsViewModel(
                      context.read<RatingApiService>(),
                      context.read<TmdbMovieService>(),
                      id,
                    )..load(),
                    child: const MyRatingsScreen(),
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

  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }
}
