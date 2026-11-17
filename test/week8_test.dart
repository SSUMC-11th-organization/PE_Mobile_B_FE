import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';

import 'support/fakes.dart';

AuthViewModel _auth({
  FakeTokenStorage? storage,
  FakeAuthApi? authApi,
  FakeMemberApi? memberApi,
}) =>
    AuthViewModel(
      authApi ?? FakeAuthApi(),
      memberApi ?? FakeMemberApi(),
      storage ?? FakeTokenStorage(),
    );

void main() {
  group('authRedirect (상태 → 화면 이동 규칙)', () {
    test('확인 중/재시도는 스플래시만 허용한다', () {
      expect(authRedirect(AuthStatus.initializing, '/home'), '/start');
      expect(authRedirect(AuthStatus.initializing, '/start'), isNull);
      expect(authRedirect(AuthStatus.retryRequired, '/login'), '/start');
    });

    test('로그아웃/로그인 중에는 /login·/register만 허용한다', () {
      expect(authRedirect(AuthStatus.signedOut, '/home'), '/login');
      expect(authRedirect(AuthStatus.signedOut, '/my/ratings'), '/login');
      expect(authRedirect(AuthStatus.signedOut, '/login'), isNull);
      expect(authRedirect(AuthStatus.signedOut, '/register'), isNull);
      expect(authRedirect(AuthStatus.authenticating, '/movies/1'), '/login');
    });

    test('로그인 상태에서는 스플래시·로그인·가입을 홈으로 보낸다', () {
      expect(authRedirect(AuthStatus.signedIn, '/start'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/login'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/register'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/my'), isNull);
    });
  });

  test('AUTH401_1(로그인 실패)은 세션 만료 코드가 아니다', () {
    expect(isSessionExpiredCode('AUTH401_1'), isFalse);
    expect(isSessionExpiredCode('AUTH401_2'), isTrue);
    expect(isSessionExpiredCode('AUTH401_3'), isTrue);
    expect(isSessionExpiredCode('AUTH401_4'), isTrue);
    expect(isSessionExpiredCode('RATING403_1'), isFalse);
  });

  group('AuthViewModel.restoreSession', () {
    test('토큰이 없으면 서버 호출 없이 signedOut', () async {
      final auth = _auth();
      await auth.restoreSession();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isFalse);
    });

    test('토큰이 있어도 GET me 성공 뒤에만 signedIn', () async {
      final auth = _auth(storage: FakeTokenStorage('t'));
      expect(auth.status, AuthStatus.initializing); // 토큰만으로 확정하지 않음
      await auth.restoreSession();
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.member?.nickname, '무비러버');
    });

    test('네트워크 실패는 retryRequired이며 토큰을 지우지 않는다', () async {
      final storage = FakeTokenStorage('t');
      final auth = _auth(
        storage: storage,
        memberApi: FakeMemberApi()..fetchError = networkError(),
      );
      await auth.restoreSession();
      expect(auth.status, AuthStatus.retryRequired);
      expect(storage.token, 't');
    });

    test('AUTH401_3은 토큰을 지우고 signedOut + 만료 플래그', () async {
      final storage = FakeTokenStorage('t');
      final auth = _auth(
        storage: storage,
        memberApi: FakeMemberApi()..fetchError = apiError('AUTH401_3', status: 401),
      );
      await auth.restoreSession();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
      expect(storage.token, isNull);
    });
  });

  group('AuthViewModel.login / logout', () {
    test('로그인 성공: 토큰 저장 후 signedIn', () async {
      final storage = FakeTokenStorage();
      final auth = _auth(storage: storage);
      await auth.login('a@b.co', 'pw');
      expect(auth.status, AuthStatus.signedIn);
      expect(storage.token, 'fake-token');
    });

    test('AUTH401_1은 폼 오류 문구만 남기고 만료 플래그는 켜지 않는다', () async {
      final storage = FakeTokenStorage();
      final auth = _auth(
        storage: storage,
        authApi: FakeAuthApi()..error = apiError('AUTH401_1', status: 401),
      );
      await auth.login('a@b.co', 'bad');
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, '이메일 또는 비밀번호를 확인해 주세요.');
      expect(auth.sessionExpired, isFalse);
      expect(storage.token, isNull);
    });

    test('직접 로그아웃은 토큰·내 정보를 지우고 만료 플래그를 켜지 않는다', () async {
      final storage = FakeTokenStorage('t');
      final auth = _auth(storage: storage);
      await auth.restoreSession();
      final before = auth.sessionVersion;

      await auth.logout();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.member, isNull);
      expect(auth.sessionExpired, isFalse);
      expect(storage.token, isNull);
      expect(auth.sessionVersion, greaterThan(before));
    });
  });

  group('MyRatingsViewModel (이번 세션 평점 저장소)', () {
    Future<(AuthViewModel, MyRatingsViewModel, FakeRatingApi)> setUpSignedIn() async {
      final auth = _auth(storage: FakeTokenStorage('t'));
      await auth.restoreSession();
      final api = FakeRatingApi();
      return (auth, MyRatingsViewModel(api, FakeTmdb(), auth), api);
    }

    test('등록 응답의 Rating이 목록에 추가되고 수정·삭제가 반영된다', () async {
      final (_, vm, _) = await setUpSignedIn();
      expect(vm.status, MyRatingsLoadStatus.empty);

      vm.addCreated(fakeRating(id: 1, score: 3), fakeMovie());
      expect(vm.ratings.length, 1);
      expect(vm.status, MyRatingsLoadStatus.success);

      await vm.updateRating(ratingId: 1, score: 5, comment: '좋아요');
      expect(vm.ratings.single.rating.score, 5);
      expect(vm.ratings.single.rating.comment, '좋아요');

      await vm.deleteRating(1);
      expect(vm.ratings, isEmpty);
      expect(vm.status, MyRatingsLoadStatus.empty);
    });

    test('403은 안내만 하고 로그인 상태와 목록을 유지한다', () async {
      final (auth, vm, api) = await setUpSignedIn();
      vm.addCreated(fakeRating(id: 1), fakeMovie());
      api.error = apiError('RATING403_1', status: 403);

      await expectLater(
        vm.deleteRating(1),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', '본인이 작성한 평점만 수정·삭제할 수 있어요.')),
      );
      expect(auth.status, AuthStatus.signedIn);
      expect(vm.ratings.length, 1);
    });

    test('AUTH401_3은 세션을 정리하고 목록을 비운다', () async {
      final (auth, vm, api) = await setUpSignedIn();
      vm.addCreated(fakeRating(id: 1), fakeMovie());
      api.error = apiError('AUTH401_3', status: 401);

      await expectLater(vm.deleteRating(1), throwsA(isA<StateError>()));
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
      expect(vm.ratings, isEmpty); // 세션 번호가 바뀌어 이전 목록이 지워짐
    });

    test('RATING404_1은 로컬 목록에서 제거한다', () async {
      final (auth, vm, api) = await setUpSignedIn();
      vm.addCreated(fakeRating(id: 1), fakeMovie());
      api.error = apiError('RATING404_1', status: 404);

      await expectLater(
          vm.updateRating(ratingId: 1, score: 4), throwsA(isA<StateError>()));
      expect(vm.ratings, isEmpty);
      expect(auth.status, AuthStatus.signedIn);
    });

    test('로그아웃하면 이전 사용자의 평점이 남지 않는다', () async {
      final (auth, vm, _) = await setUpSignedIn();
      vm.addCreated(fakeRating(id: 1), fakeMovie());
      await auth.logout();
      expect(vm.ratings, isEmpty);
    });
  });

  group('EditProfileViewModel', () {
    Future<(AuthViewModel, FakeMemberApi, EditProfileViewModel)> setUpEdit() async {
      final memberApi = FakeMemberApi();
      final auth = _auth(storage: FakeTokenStorage('t'), memberApi: memberApi);
      await auth.restoreSession();
      return (auth, memberApi, EditProfileViewModel(memberApi, auth));
    }

    test('2자 미만이면 요청 없이 검증 오류', () async {
      final (_, api, vm) = await setUpEdit();
      expect(await vm.save('a'), isFalse);
      expect(vm.nicknameError, '닉네임은 2~12자로 입력해 주세요.');
      expect(api.updateCalls, 0);
    });

    test('현재 닉네임과 같으면 요청 없이 성공 처리', () async {
      final (_, api, vm) = await setUpEdit();
      expect(await vm.save('무비러버'), isTrue);
      expect(api.updateCalls, 0);
    });

    test('성공하면 AuthViewModel.member가 교체된다', () async {
      final (auth, _, vm) = await setUpEdit();
      expect(await vm.save('새닉네임'), isTrue);
      expect(auth.member?.nickname, '새닉네임');
    });

    test('MEMBER409_1은 필드 오류로 남고 로그아웃하지 않는다', () async {
      final (auth, api, vm) = await setUpEdit();
      api.updateError = apiError('MEMBER409_1', status: 409);
      expect(await vm.save('중복닉'), isFalse);
      expect(vm.nicknameError, '이미 사용 중인 닉네임이에요.');
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.member?.nickname, '무비러버');
    });

    test('네트워크 오류는 Snackbar 메시지로 안내하고 로그아웃하지 않는다', () async {
      final (auth, api, vm) = await setUpEdit();
      api.updateError = networkError();
      expect(await vm.save('새닉네임'), isFalse);
      expect(vm.message, isNotNull);
      expect(auth.status, AuthStatus.signedIn);
    });

    test('AUTH401_2는 세션을 정리한다', () async {
      final (auth, api, vm) = await setUpEdit();
      api.updateError = apiError('AUTH401_2', status: 401);
      expect(await vm.save('새닉네임'), isFalse);
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
    });
  });
}

