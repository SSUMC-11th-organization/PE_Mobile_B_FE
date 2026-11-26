import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/services/api_response.dart';
import '../data/services/member_api_service.dart';
import 'auth_view_model.dart';

enum ProfileSaveStatus { idle, saving, success, error }

// 프로필 수정(/my/profile/edit) — 닉네임만 PATCH /v8/members/me로 저장
// 오류는 classifyApiError로 분류 — 세션 만료(401 AUTH401_2/3/4)는 인터셉터가 전역 처리하므로 여기선 문구 없이 정리만
class ProfileEditViewModel extends ChangeNotifier {
  ProfileEditViewModel(this._memberApi, this._auth);

  static const minLength = 2;
  static const maxLength = 12;

  final MemberApiService _memberApi;
  final AuthViewModel _auth;
  bool _disposed = false;

  ProfileSaveStatus status = ProfileSaveStatus.idle;
  String? fieldError; // 입력칸 아래 — 닉네임 중복(conflict), 서버 검증 실패(validation)
  String? generalError; // 버튼 위 — 권한 없음·네트워크 실패 등 (다시 저장 버튼으로 재시도)

  bool get isSaving => status == ProfileSaveStatus.saving;

  // 클라이언트 검증 — 위반 시 입력칸 아래 문구, 통과하면 null
  static String? validateNickname(String? value) {
    final nickname = value?.trim() ?? '';
    if (nickname.isEmpty) return '닉네임을 입력해 주세요.';
    if (nickname.length < minLength || nickname.length > maxLength) {
      return '닉네임은 $minLength~$maxLength자로 입력해 주세요.';
    }
    return null;
  }

  // 입력이 바뀌면 이전 서버 오류 문구를 지움 (입력값은 화면 컨트롤러에 그대로 유지)
  void onNicknameChanged() {
    if (fieldError == null && generalError == null) return;
    fieldError = null;
    generalError = null;
    if (status == ProfileSaveStatus.error) status = ProfileSaveStatus.idle;
    _notify();
  }

  // 성공하면 AuthViewModel.member를 응답 MemberInfo로 교체하고 true
  Future<bool> save(String nickname) async {
    if (isSaving) return false; // 저장 중 중복 호출 무시
    final version = _auth.sessionVersion; // 요청을 시작한 세션
    status = ProfileSaveStatus.saving;
    fieldError = null;
    generalError = null;
    _notify();

    try {
      final updated = await _memberApi.updateNickname(nickname.trim());
      // 화면을 벗어났더라도 서버에는 반영됐으므로 같은 세션이면 member는 갱신
      final applied = _auth.replaceMember(updated, sessionVersion: version);
      if (_disposed) return false;
      if (!applied) {
        _releaseQuietly(); // 로그아웃/세션 만료/회원 전환 뒤 늦게 온 응답 → 버림
        return false;
      }
      status = ProfileSaveStatus.success;
      _notify();
      return true;
    } on DioException catch (e) {
      if (_disposed) return false;
      final kind = classifyApiError(e);
      // 세션 만료이거나 그 사이 세션이 바뀌었으면 문구 없이 저장 중 상태만 해제 (redirect로 화면이 사라짐)
      if (kind == ApiErrorKind.sessionExpired || _auth.sessionVersion != version) {
        _releaseQuietly();
        return false;
      }
      _applyError(kind, apiErrorMessage(e));
    } on InvalidApiResponseException {
      if (_disposed) return false;
      generalError = '저장 결과를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
    status = ProfileSaveStatus.error;
    _notify();
    return false;
  }

  // 세션은 유지 — 토큰 삭제·로그아웃 없음
  void _applyError(ApiErrorKind kind, String? serverMessage) {
    switch (kind) {
      case ApiErrorKind.conflict:
        fieldError = serverMessage ?? '이미 사용 중인 닉네임입니다. 다른 닉네임을 입력해 주세요.';
      case ApiErrorKind.validation:
        fieldError = serverMessage ?? '닉네임을 다시 확인해 주세요.';
      case ApiErrorKind.forbidden:
        generalError = serverMessage ?? '닉네임을 변경할 권한이 없습니다.';
      case ApiErrorKind.network:
        generalError = '네트워크 연결을 확인한 뒤 다시 저장해 주세요.';
      case ApiErrorKind.server:
        generalError = '서버에 문제가 발생했습니다. 잠시 후 다시 저장해 주세요.';
      case ApiErrorKind.sessionExpired:
      case ApiErrorKind.loginFailed:
      case ApiErrorKind.unknown:
        generalError = serverMessage ?? '닉네임을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
  }

  void _releaseQuietly() {
    status = ProfileSaveStatus.idle;
    fieldError = null;
    generalError = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
