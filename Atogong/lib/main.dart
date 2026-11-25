import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/core/network/movielog_client.dart';
import 'package:movielog/core/session/auth_session_bridge.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env'); // runApp 전에 로드가 끝나야 토큰을 읽을 수 있음
  runApp(const MovieLogApp());
}

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tokenStorage = SecureTokenStorage(const FlutterSecureStorage());
    final publicClient = createMovieLogClient(); // Interceptor 없음
    final authClient = createAuthMovieLogClient(tokenStorage); // Interceptor 등록

    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: tokenStorage),
        // 상태 없는 Service는 앱 전체에서 하나를 공유. 화면별 ViewModel은 라우터에서 생성.
        // TMDB Client에는 AuthInterceptor를 붙이지 않음 (TMDB 요청에 MovieLog JWT가 실리면 안 됨)
        Provider<TmdbMovieService>(
          create: (_) => TmdbMovieService(createTmdbClient()),
        ),
        // 공개 Client: 로그인, 회원가입·중복 체크
        Provider<AuthApiService>(create: (_) => AuthApiService(publicClient)),
        Provider<SignUpService>(create: (_) => SignUpService(publicClient)),
        // 보호 Client: 내 정보. RatingApiService는 공개 조회용 publicClient도 함께 받음
        Provider<MemberApiService>(create: (_) => MemberApiService(authClient)),
        Provider<RatingApiService>(
          create: (_) => RatingApiService(publicClient, authClient),
        ),
        // Service가 모두 등록된 뒤 생성자로 주입받는 인증 ViewModel
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<AuthApiService>(),
            context.read<MemberApiService>(),
            context.read<TokenStorage>(),
          ),
        ),
        // 9주차: AuthViewModel의 세션 변화를 SessionGuard에 전달. 인증 상태의 기준은 여전히 AuthViewModel
        Provider<AuthSessionBridge>(
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
        // 이번 로그인 세션에서 등록한 평점. 영화 상세(등록)와 마이페이지(수정·삭제)가 같이 읽고, 세션이 바뀌면 비워짐
        ChangeNotifierProvider<SessionRatings>(
          create: (context) => SessionRatings(context.read<AuthViewModel>()),
        ),
      ],
      child: const _MovieLogRouterApp(),
    );
  }
}

/// GoRouter는 앱이 살아 있는 동안 한 번만 만들어야 함.
/// build()에서 만들면 다시 그려질 때마다 Router가 새로 생겨 현재 위치가 초기화되므로 initState에서 생성
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
    _router = AppRouter.createRouter(authViewModel);
    // 첫 build 이후 세션 복원 시작 (저장된 토큰 읽기 → GET me 검증)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) authViewModel.restoreSession();
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
