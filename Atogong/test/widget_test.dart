import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/view_models/auth_view_model.dart';

// 8주차: 인증 상태별 화면 이동 규칙(authRedirect) 확인.
// 네트워크·secure storage 없이 돌릴 수 있도록 순수 함수만 테스트
void main() {
  group('authRedirect', () {
    test('토큰 확인 중·확인 실패에는 스플래시(/start)에 머문다', () {
      expect(authRedirect(AuthStatus.initializing, '/start'), isNull);
      expect(authRedirect(AuthStatus.initializing, '/home'), '/start');
      expect(authRedirect(AuthStatus.retryRequired, '/my'), '/start');
    });

    test('로그아웃 상태에서는 공개 화면만 허용하고 나머지는 /login으로 보낸다', () {
      expect(authRedirect(AuthStatus.signedOut, '/login'), isNull);
      expect(authRedirect(AuthStatus.signedOut, '/register'), isNull);
      expect(authRedirect(AuthStatus.signedOut, '/start'), '/login');
      expect(authRedirect(AuthStatus.signedOut, '/my/ratings'), '/login');
      expect(authRedirect(AuthStatus.authenticating, '/home'), '/login');
    });

    test('로그인 상태에서는 스플래시·로그인·회원가입 화면을 /home으로 보낸다', () {
      expect(authRedirect(AuthStatus.signedIn, '/start'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/login'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/register'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/my/profile/edit'), isNull);
    });
  });
}
