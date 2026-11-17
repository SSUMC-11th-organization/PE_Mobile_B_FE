import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/services/member_api_service.dart';
import 'auth_view_model.dart';

enum EditProfileStatus { idle, saving, success, failure }

/// 프로필(닉네임) 수정 화면 전용. 오류는 보여줄 위치에 따라 나눔:
/// 입력칸의 문제(길이·중복)는 nicknameError로 필드 아래에, 입력과 무관한 문제(네트워크)는 message로 Snackbar에
class EditProfileViewModel extends ChangeNotifier {
  EditProfileViewModel(this._memberApi, this._auth);

  final MemberApiService _memberApi;
  final AuthViewModel _auth;

  EditProfileStatus status = EditProfileStatus.idle;
  String? nicknameError;
  String? message;
  bool _disposed = false;

  // 서버에 보내기 전에 확인할 수 있는 규칙은 먼저 검사해 불필요한 통신을 줄임 (서버 검증을 대체하지는 않음)
  String? validateNickname(String value) {
    final nickname = value.trim();
    if (nickname.length < 2 || nickname.length > 12) {
      return '닉네임은 2~12자로 입력해 주세요.';
    }
    return null;
  }

  Future<bool> save(String input) async {
    if (status == EditProfileStatus.saving) return false; // 중복 탭 방지

    final version = _auth.sessionVersion;
    if (_disposed ||
        _auth.status != AuthStatus.signedIn ||
        _auth.member == null) {
      return false;
    }
    final nickname = input.trim();
    nicknameError = validateNickname(nickname);
    if (nicknameError != null) {
      _notify();
      return false;
    }

    // 현재 닉네임과 같으면 요청 없이 완료 처리 (자기 자신은 중복이 아니라 409도 아님)
    if (nickname == _auth.member?.nickname) {
      status = EditProfileStatus.success;
      _notify();
      return true;
    }

    status = EditProfileStatus.saving;
    nicknameError = null;
    message = null;
    _notify();

    try {
      final updated = await _memberApi.updateNickname(nickname);
      if (_disposed ||
          version != _auth.sessionVersion ||
          _auth.status != AuthStatus.signedIn) {
        return false;
      }
      _auth.updateMember(updated); // 마이페이지가 바로 새 닉네임을 보여줌
      status = EditProfileStatus.success;
      _notify();
      return true;
    } on DioException catch (error) {
      if (_disposed ||
          version != _auth.sessionVersion ||
          _auth.status != AuthStatus.signedIn) {
        return false;
      }
      final code = apiErrorCode(error);
      status = EditProfileStatus.failure;
      switch (code) {
        case 'AUTH401_2' || 'AUTH401_3' || 'AUTH401_4':
          // 세션 만료: 안내와 이동은 로그인 화면과 Router가 처리
          await _auth.expireSession();
        case 'MEMBER409_1':
          nicknameError = '이미 사용 중인 닉네임이에요.'; // 입력값은 유지
        case 'COMMON400':
          nicknameError = apiErrorMessage(error) ?? '닉네임 형식을 확인해 주세요.';
        case 'MEMBER404_1':
          message = '회원 정보를 찾을 수 없어요.';
        default:
          message = '네트워크 상태를 확인하고 다시 시도해 주세요.'; // 로그아웃하지 않음
      }
    } catch (_) {
      if (_disposed || version != _auth.sessionVersion) return false;
      status = EditProfileStatus.failure;
      message = '알 수 없는 오류가 발생했어요.';
    }
    _notify();
    return false;
  }

  // 화면이 사라진 뒤 도착한 응답이 notifyListeners()를 호출하지 않게 막음
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
