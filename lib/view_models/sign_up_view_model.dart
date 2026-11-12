import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/create_member_request.dart';
import '../data/services/sign_up_service.dart';

enum CheckStatus { idle, checking, available, duplicated, error }

enum SubmitStatus { idle, submitting, success, error }

// 필드 하나(닉네임 또는 이메일)의 중복 확인 상태 — 로직은 SignUpViewModel이 공유
class _FieldCheck {
  _FieldCheck(this.duplicatedMessage);

  final String duplicatedMessage;
  CheckStatus status = CheckStatus.idle;
  String? errorText;
  String? duplicatedValue; // 마지막으로 서버가 "중복"이라고 한 값
  String current = '';
  int version = 0;

  bool get canCheck =>
      current.isNotEmpty &&
      status != CheckStatus.checking &&
      status != CheckStatus.duplicated;
}

// 회원가입 화면의 닉네임/이메일 중복 확인 + 회원가입 제출 상태 관리
class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service);

  final SignUpService _service;
  bool _disposed = false;
  final _nickname = _FieldCheck('이미 사용 중인 닉네임입니다.');
  final _email = _FieldCheck('이미 사용 중인 이메일입니다.');

  SubmitStatus submitStatus = SubmitStatus.idle;
  int? createdMemberId; // 가입 성공 시 서버가 준 memberId
  String? passwordErrorText; // 서버가 비밀번호 규칙 위반(400)을 알려준 경우
  String? snackbarMessage; // 그 외 제출 실패 안내 (화면이 SnackBar로 표시)

  CheckStatus get nicknameCheckStatus => _nickname.status;
  String? get nicknameErrorText => _nickname.errorText;
  bool get canCheckNickname => _nickname.canCheck;
  CheckStatus get emailCheckStatus => _email.status;
  String? get emailErrorText => _email.errorText;
  bool get canCheckEmail => _email.canCheck;
  bool get bothAvailable =>
      _nickname.status == CheckStatus.available &&
      _email.status == CheckStatus.available;

  void onNicknameChanged(String v) => _onChanged(_nickname, v);
  void onEmailChanged(String v) => _onChanged(_email, v);
  Future<void> checkNickname(String v) =>
      _check(_nickname, v, _service.checkNickname);
  Future<void> checkEmail(String v) => _check(_email, v, _service.checkEmail);

  // 비밀번호를 다시 입력하면 서버가 준 비밀번호 오류 문구를 지움 (값은 받지 않음)
  void onPasswordChanged() {
    if (passwordErrorText == null) return;
    passwordErrorText = null;
    _notify();
  }

  Future<void> submit(CreateMemberRequest request) async {
    if (submitStatus == SubmitStatus.submitting) return; // 제출 중 중복 호출 무시
    submitStatus = SubmitStatus.submitting;
    createdMemberId = null;
    passwordErrorText = null;
    snackbarMessage = null;
    _notify();
    try {
      final response = await _service.signUp(request);
      if (_disposed) return;
      final memberId = response.result?.memberId;
      if (memberId == null) {
        submitStatus = SubmitStatus.error;
        snackbarMessage = '회원 정보를 확인하지 못했습니다. 다시 시도해 주세요.';
      } else {
        createdMemberId = memberId;
        submitStatus = SubmitStatus.success;
      }
    } on DioException catch (e) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      final message = writeSignUpErrorMessage(e);
      if (e.response?.statusCode == 400 && message.contains('비밀번호')) {
        passwordErrorText = message;
      } else {
        snackbarMessage = message; // 그 외 400·409·네트워크 오류
      }
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _onChanged(_FieldCheck f, String value) {
    final t = value.trim();
    f.current = t;
    f.version++; // 진행 중 응답 무효화
    if (f.duplicatedValue != null && t == f.duplicatedValue) {
      f.status = CheckStatus.duplicated; // API 재호출 없이 즉시 에러 복원
      f.errorText = f.duplicatedMessage;
    } else {
      f.status = CheckStatus.idle;
      f.errorText = null;
    }
    _clearSubmitError();
    _notify();
  }

  // 입력이 바뀌면 이전 제출 실패 결과는 더 이상 유효하지 않음
  void _clearSubmitError() {
    snackbarMessage = null;
    passwordErrorText = null;
    if (submitStatus == SubmitStatus.error) submitStatus = SubmitStatus.idle;
  }

  Future<void> _check(
    _FieldCheck f,
    String value,
    Future<bool> Function(String) call,
  ) async {
    final requested = value.trim();
    if (requested.isEmpty || requested != f.current || !f.canCheck) return;
    final version = ++f.version;
    f.status = CheckStatus.checking;
    f.errorText = null;
    _notify();
    try {
      final available = await call(requested);
      if (_disposed || version != f.version || f.current != requested) return;
      if (available) {
        f.status = CheckStatus.available;
        f.errorText = null;
      } else {
        f.status = CheckStatus.duplicated;
        f.errorText = f.duplicatedMessage;
        f.duplicatedValue = requested;
      }
    } on DioException {
      if (_disposed || version != f.version || f.current != requested) return;
      f.status = CheckStatus.error;
      f.errorText = '중복 확인에 실패했습니다. 다시 시도해 주세요.';
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _nickname.version++;
    _email.version++;
    super.dispose();
  }
}
