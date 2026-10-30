import 'package:flutter/material.dart';
import 'package:jay/core/network/tmdb_client.dart';
import 'package:jay/data/services/tmdb_movie_service.dart';
import 'package:jay/router/app_router.dart';
import 'package:jay/theme/app_theme.dart';
import 'package:provider/provider.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TmdbMovieService>(
          create: (_) => TmdbMovieService(createTmdbClient()),
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
