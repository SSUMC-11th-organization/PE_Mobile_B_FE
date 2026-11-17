import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/debug/debug_fab.dart';
import 'core/network/backend_client.dart';
import 'core/network/movie_log_client.dart';
import 'core/network/tmdb_client.dart';
import 'core/storage/token_storage.dart';
import 'data/services/auth_api_service.dart';
import 'data/services/backend_service.dart';
import 'data/services/member_api_service.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/sign_up_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'screens/debug_failure_screen.dart';
import 'theme/app_theme.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/my_ratings_view_model.dart';

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
    this.tokenStorage,
    this.authApiService,
    this.memberApiService,
  });

  // 테스트에서 가짜 구현을 주입하기 위한 선택 인자입니다.
  final SignUpService? signUpService;
  final RatingApiService? ratingApiService;
  final TmdbMovieService? tmdbMovieService;
  final TokenStorage? tokenStorage;
  final AuthApiService? authApiService;
  final MemberApiService? memberApiService;

  @override
  Widget build(BuildContext context) {
    final storage =
        tokenStorage ?? SecureTokenStorage(const FlutterSecureStorage());
    final publicClient = createMovieLogClient(); // 토큰을 붙이지 않는 공개 Client
    final authClient = createAuthMovieLogClient(storage); // Bearer를 붙이는 보호 Client

    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: storage),
        // TMDB Client에는 MovieLog 토큰이 실리지 않습니다. 합치지 않습니다.
        Provider<TmdbMovieService>(
          create: (_) =>
              tmdbMovieService ?? TmdbMovieService(createTmdbClient()),
        ),
        // 공개 Client
        Provider<AuthApiService>(
          create: (_) => authApiService ?? AuthApiService(publicClient),
        ),
        Provider<SignUpService>(
          create: (_) => signUpService ?? SignUpService(publicClient),
        ),
        // 보호 Client
        Provider<MemberApiService>(
          create: (_) => memberApiService ?? MemberApiService(authClient),
        ),
        // 평점: 조회(공개)는 publicClient, 등록·수정·삭제(보호)는 authClient
        Provider<RatingApiService>(
          create: (_) =>
              ratingApiService ?? RatingApiService(publicClient, authClient),
        ),
        // 기존 코드와의 호환성을 위한 BackendService 유지
        Provider<BackendService>(
          create: (_) => BackendService(createBackendClient()),
        ),
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<AuthApiService>(),
            context.read<MemberApiService>(),
            context.read<TokenStorage>(),
          ),
        ),
        // 등록 화면과 목록 화면이 공유하는 이번 세션의 평점 저장소
        ChangeNotifierProvider<MyRatingsViewModel>(
          create: (context) => MyRatingsViewModel(
            context.read<RatingApiService>(),
            context.read<TmdbMovieService>(),
            context.read<AuthViewModel>(),
          ),
        ),
      ],
      child: const _MovieLogRouterApp(),
    );
  }
}

/// GoRouter는 앱 수명 동안 한 번만 만들어야 하므로 Stateful로 분리합니다.
/// build()에서 만들면 다시 그려질 때마다 위치가 초기화됩니다.
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
    final auth = context.read<AuthViewModel>();
    _router = AppRouter.createRouter(auth);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) auth.restoreSession(); // 첫 build 이후 세션 복원을 시작합니다.
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
    );
  }
}
