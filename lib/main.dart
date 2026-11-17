import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/debug/debug_fab.dart';
import 'core/network/backend_client.dart';
import 'core/network/movie_log_client.dart';
import 'core/network/tmdb_client.dart';
import 'data/services/backend_service.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/sign_up_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'screens/debug_failure_screen.dart';
import 'theme/app_theme.dart';
import 'view_models/learning_member_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MovieLogApp());
}

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({
    super.key,
    this.signUpService,
    this.ratingApiService,
    this.tmdbMovieService,
  });

  final SignUpService? signUpService;
  final RatingApiService? ratingApiService;
  final TmdbMovieService? tmdbMovieService;

  @override
  Widget build(BuildContext context) {
    final movieLogClient = createMovieLogClient();

    return MultiProvider(
      providers: [
        Provider<TmdbMovieService>(
          create: (_) =>
              tmdbMovieService ?? TmdbMovieService(createTmdbClient()),
        ),
        ChangeNotifierProvider<LearningMemberSession>(
          create: (_) => LearningMemberSession(),
        ),
        Provider<SignUpService>(
          create: (_) => signUpService ?? SignUpService(movieLogClient),
        ),
        Provider<RatingApiService>(
          create: (_) =>
              ratingApiService ?? RatingApiService(movieLogClient),
        ),
        // 기존 코드와의 호환성을 위한 BackendService 유지
        Provider<BackendService>(
          create: (_) => BackendService(createBackendClient()),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'MovieLog',
        theme: AppTheme.light,
        routerConfig: AppRouter.router,
        builder: (context, child) => Stack(
          children: [
            child ?? const SizedBox.shrink(),
            // 디버그 전용: 화면 위에 떠 있는 드래그 가능한 실패 시뮬레이션 버튼
            if (kDebugMode)
              DebugFab(
                onTap: () => AppRouter.rootNavigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => const DebugFailureScreen(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
