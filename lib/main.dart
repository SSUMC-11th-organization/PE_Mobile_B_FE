// flutter/material.dart 안에 MaterialApp, Scaffold, Text, Icon, ElevatedButton 등
// 자주 쓰는 Widget들이 다 들어있어서 이 한 줄로 전부 가져다 씀
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'theme/app_theme.dart';  
import 'screens/sign_up_screen.dart';


// 앱이 시작될 때 제일 먼저 실행되는 함수. Dart의 모든 프로그램은 main()에서 시작해
Future<void> main() async {
  // runApp 전에 asset(.env)을 읽으려면 Flutter 엔진 바인딩을 먼저 초기화해야 함
  WidgetsFlutterBinding.ensureInitialized();
  // .env의 TMDB_ACCESS_TOKEN 등을 메모리에 로드 (파일은 pubspec.yaml assets에 등록돼 있어야 함)
  await dotenv.load(fileName: '.env');

  // runApp()에 "가장 바깥쪽 Widget"을 넘겨주면 Flutter가 그걸 화면에 그리기 시작함
  runApp(const MovieLogApp());
}

// StatelessWidget = "상태(state)가 없는 위젯" = 한번 그려지면 스스로 안 바뀌는 화면
// 지금 이 앱은 버튼 눌러도 숫자가 바뀌거나 하지 않으니까 StatelessWidget으로 충분해
class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key}); // 생성자. key는 Flutter가 위젯을 구분하는 이름표 정도로 생각하면 됨

  @override
  // build()는 "이 위젯이 화면에 뭘 그려야 하는지"를 리턴하는 함수
  // BuildContext context는 "지금 이 위젯이 Widget Tree의 어디쯤 있는지"에 대한 정보
  Widget build(BuildContext context) {
    // MaterialApp.router = 화면 이동을 GoRouter에 맡기는 MaterialApp
    return MaterialApp.router(
      debugShowCheckedModeBanner: false, // 우측 상단에 뜨는 빨간 DEBUG 띠 안 보이게
      title: 'MovieLog', // 브라우저 탭 제목 등에 쓰임
      theme: AppTheme.light,
      routerConfig: AppRouter.router, // 첫 화면·경로 목록은 AppRouter에서 관리
    );
  }
}
