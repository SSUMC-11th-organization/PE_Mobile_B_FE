import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/network/backend_client.dart';
import 'core/network/movie_log_client.dart';
import 'core/network/tmdb_client.dart';
import 'data/services/backend_service.dart';
import 'data/services/member_check_service.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MovieLogApp());
}

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({
    super.key,
    this.memberCheckService,
    this.ratingApiService,
    this.tmdbMovieService,
  });

  final MemberCheckService? memberCheckService;
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
        Provider<MemberCheckService>(
          create: (_) =>
              memberCheckService ?? MemberCheckService(movieLogClient),
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
      ),
    );
  }
}
