// flutter/material.dart 안에 MaterialApp, Scaffold, Text, Icon, ElevatedButton 등
// 자주 쓰는 Widget들이 다 들어있어서 이 한 줄로 전부 가져다 씀
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/network/movie_log_client.dart';
import 'core/storage/token_storage.dart';
import 'data/services/auth_service.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/sign_up_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/learning_member_session.dart';


// 앱이 시작될 때 제일 먼저 실행되는 함수. Dart의 모든 프로그램은 main()에서 시작해
Future<void> main() async {
  // runApp 전에 asset(.env)을 읽으려면 Flutter 엔진 바인딩을 먼저 초기화해야 함
  WidgetsFlutterBinding.ensureInitialized();
  // .env의 TMDB_ACCESS_TOKEN 등을 메모리에 로드 (파일은 pubspec.yaml assets에 등록돼 있어야 함)
  await dotenv.load(fileName: '.env');

  // runApp()에 "가장 바깥쪽 Widget"을 넘겨주면 Flutter가 그걸 화면에 그리기 시작함
  runApp(const MovieLogApp());
}

// StatefulWidget — AuthViewModel과 GoRouter를 앱 수명 동안 한 번만 만들고 dispose하기 위해 State가 필요
class MovieLogApp extends StatefulWidget {
  const MovieLogApp({super.key}); // 생성자. key는 Flutter가 위젯을 구분하는 이름표 정도로 생각하면 됨

  // build마다 새로 만들지 않도록 앱 전체에서 한 번만 생성
  // MovieLog JWT 저장소 — 보호용 Dio의 AuthInterceptor와 Provider가 같은 인스턴스를 공유
  static final TokenStorage tokenStorage = SecureTokenStorage();
  // 워크북 서버 공개용 Dio (Authorization 없음) — TMDB Dio와 별개
  static final movieLogPublicClient = MovieLogPublicClient();
  // 워크북 서버 보호용 Dio (MovieLog JWT만 Bearer로 첨부) — TMDB Dio와 별개
  static final movieLogAuthClient = MovieLogAuthClient(tokenStorage);
  // 로그인(공개용 Dio) + 내 정보(보호용 Dio)
  static final authService =
      AuthService(movieLogPublicClient, movieLogAuthClient);

  @override
  State<MovieLogApp> createState() => _MovieLogAppState();
}

class _MovieLogAppState extends State<MovieLogApp> {
  // 앱 시작 시 저장된 토큰으로 세션 복원 → 결과에 따라 router redirect가 화면을 정함
  late final AuthViewModel _auth = AuthViewModel(
    MovieLogApp.authService,
    MovieLogApp.tokenStorage,
  )..restoreSession();
  late final GoRouter _router = AppRouter.createRouter(_auth);

  @override
  void dispose() {
    _router.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  // build()는 "이 위젯이 화면에 뭘 그려야 하는지"를 리턴하는 함수
  // BuildContext context는 "지금 이 위젯이 Widget Tree의 어디쯤 있는지"에 대한 정보
  Widget build(BuildContext context) {
    // MultiProvider를 MaterialApp 바깥에 둬서 모든 라우트(화면)에서 서비스를 꺼내 쓸 수 있게 함
    return MultiProvider(
      providers: [
        // 앱 전체에서 TmdbMovieService(= Dio 인스턴스) 하나를 공유
        Provider<TmdbMovieService>(create: (_) => TmdbMovieService()),
        // 토큰 저장소 + MovieLog 공개용/보호용 클라이언트 (로그인·v7 전환 단계에서 사용)
        Provider<TokenStorage>.value(value: MovieLogApp.tokenStorage),
        Provider<MovieLogPublicClient>.value(
          value: MovieLogApp.movieLogPublicClient,
        ),
        Provider<MovieLogAuthClient>.value(
          value: MovieLogApp.movieLogAuthClient,
        ),
        Provider<AuthService>.value(value: MovieLogApp.authService),
        // 앱 전체 인증 상태 — dispose는 State가 직접 하므로 .value로 제공
        ChangeNotifierProvider<AuthViewModel>.value(value: _auth),
        // 닉네임/이메일 중복 확인 + 회원가입 — 공개용 Dio 사용
        Provider<SignUpService>(
          create: (_) => SignUpService(MovieLogApp.movieLogPublicClient.dio),
        ),
        // 평점 v6 조회/등록/수정/삭제 — 기존 동작 유지를 위해 아직 공개용 Dio 사용 (v7 전환 시 보호용으로 이동)
        Provider<RatingApiService>(
          create: (_) =>
              RatingApiService(MovieLogApp.movieLogPublicClient.dio),
        ),
        // 회원가입으로 받은 학습용 memberId (앱 실행 중 메모리에만 보관)
        ChangeNotifierProvider<LearningMemberSession>(
          create: (_) => LearningMemberSession(),
        ),
      ],
      // MaterialApp.router = 화면 이동을 GoRouter에 맡기는 MaterialApp
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false, // 우측 상단에 뜨는 빨간 DEBUG 띠 안 보이게
        title: 'MovieLog', // 브라우저 탭 제목 등에 쓰임
        theme: AppTheme.light,
        routerConfig: _router, // 경로 목록·인증 redirect는 AppRouter에서 관리
      ),
    );
  }
}
