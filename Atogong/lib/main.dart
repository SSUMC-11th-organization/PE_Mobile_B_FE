import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:movielog/core/network/movielog_client.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/view_models/learning_member_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env'); // runApp 전에 로드가 끝나야 토큰을 읽을 수 있음
  runApp(const MovieLogApp());
}

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    final movieLogClient = createMovieLogClient();
    return MultiProvider(
      providers: [
        // 회원가입 결과의 memberId를 영화 상세·마이페이지가 같이 읽도록 앱 최상단에 둠
        ChangeNotifierProvider<LearningMemberSession>(
          create: (_) => LearningMemberSession(),
        ),
        // 상태 없는 Service는 앱 전체에서 하나를 공유. 화면별 ViewModel은 라우터에서 생성
        Provider<TmdbMovieService>(
          create: (_) => TmdbMovieService(createTmdbClient()),
        ),
        // 자체 백엔드(회원·평점)는 TMDB와 별도 Client로 분리. 두 Service가 Dio 하나를 공유
        Provider<SignUpService>(create: (_) => SignUpService(movieLogClient)),
        Provider<RatingApiService>(
          create: (_) => RatingApiService(movieLogClient),
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
