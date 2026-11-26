import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:jay/core/network/movie_log_client.dart';
import 'package:jay/core/network/tmdb_client.dart';
import 'package:jay/core/session/auth_session_bridge.dart';
import 'package:jay/core/session/session_guard.dart';
import 'package:jay/data/services/auth_api_service.dart';
import 'package:jay/data/services/favorite_api_service.dart';
import 'package:jay/data/services/member_api_service.dart';
import 'package:jay/data/services/rating_api_service.dart';
import 'package:jay/data/services/sign_up_service.dart';
import 'package:jay/data/services/tmdb_movie_service.dart';
import 'package:jay/router/app_router.dart';
import 'package:jay/storage/install_flag.dart';
import 'package:jay/storage/saved_email_storage.dart';
import 'package:jay/storage/token_storage.dart';
import 'package:jay/theme/app_theme.dart';
import 'package:jay/view_models/auth_view_model.dart';
import 'package:jay/view_models/learning_member_session.dart';
import 'package:jay/view_models/session_rating_store.dart';
import 'package:provider/provider.dart';

class MovieLogApp extends StatefulWidget {
  const MovieLogApp({super.key});

  @override
  State<MovieLogApp> createState() => _MovieLogAppState();
}

class _MovieLogAppState extends State<MovieLogApp> {
  // build()가 다시 실행돼도 Client·Storage가 새로 만들어지지 않도록 State에 한 번만 만듭니다.
  late final TokenStorage _tokenStorage = SecureTokenStorage(
    const FlutterSecureStorage(),
  );
  late final _publicClient = createMovieLogClient(); // Interceptor 없음
  late final _authClient = createAuthMovieLogClient(_tokenStorage); // Bearer 등록

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: _tokenStorage),
        Provider<SavedEmailStorage>(create: (_) => SavedEmailStorage()),
        // TMDB Client에는 MovieLog AuthInterceptor를 붙이지 않습니다.
        Provider<TmdbMovieService>(
          create: (_) => TmdbMovieService(createTmdbClient()),
        ),
        // 공개 Client: 로그인, 회원가입·중복 확인
        Provider<AuthApiService>(create: (_) => AuthApiService(_publicClient)),
        Provider<SignUpService>(create: (_) => SignUpService(_publicClient)),
        // 보호 Client: 내 정보 / 평점은 공개 조회용 Client도 함께 받음
        Provider<MemberApiService>(
          create: (_) => MemberApiService(_authClient),
        ),
        Provider<RatingApiService>(
          create: (_) => RatingApiService(_publicClient, _authClient),
        ),
        // authClient는 8주차에서 만든 보호용 Dio입니다. 새로 만들지 않고 기존 인스턴스를 사용합니다.
        Provider<FavoriteApiService>(
          create: (_) => FavoriteApiService(_authClient),
        ),
        ChangeNotifierProvider<LearningMemberSession>(
          create: (_) => LearningMemberSession(),
        ),
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<AuthApiService>(),
            context.read<MemberApiService>(),
            context.read<TokenStorage>(),
            installFlag: InstallFlag(context.read<TokenStorage>()),
          ),
        ),
        // AuthViewModel을 읽으므로 반드시 AuthViewModel보다 아래에 둡니다.
        // lazy: false — 로그인 상태 변화를 처음부터 SessionGuard에 반영하도록 바로 만듭니다.
        Provider<AuthSessionBridge>(
          lazy: false,
          create: (context) {
            final auth = context.read<AuthViewModel>();
            return AuthSessionBridge(
              authSignals: auth,
              sessionVersion: () => auth.sessionVersion,
              verifiedEmail: () => auth.status == AuthStatus.signedIn
                  ? auth.member?.email
                  : null,
            );
          },
          dispose: (_, bridge) => bridge.dispose(),
        ),
        Provider<SessionGuard>(
          create: (context) => context.read<AuthSessionBridge>().guard,
        ),
        // 세션이 바뀌면(로그인·로그아웃·만료) 이전 세션에서 등록한 평점을 비웁니다.
        ChangeNotifierProxyProvider<AuthViewModel, SessionRatingStore>(
          create: (_) => SessionRatingStore(),
          update: (_, auth, store) =>
              (store ?? SessionRatingStore())..syncSession(auth.sessionVersion),
        ),
      ],
      child: const _MovieLogRouterApp(),
    );
  }
}

class _MovieLogRouterApp extends StatefulWidget {
  const _MovieLogRouterApp();

  @override
  State<_MovieLogRouterApp> createState() => _MovieLogRouterAppState();
}

class _MovieLogRouterAppState extends State<_MovieLogRouterApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authViewModel = context.read<AuthViewModel>();
    _router = AppRouter.createRouter(authViewModel); // Router는 한 번만 만듭니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) authViewModel.restoreSession(); // 첫 build 이후 세션 복원 시작
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
