import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jay/data/models/create_member_request.dart';
import 'package:jay/data/services/sign_up_service.dart';

enum CheckStatus { idle, checking, available, duplicated, error }

enum SubmitStatus { idle, submitting, success, error }

class SignupViewModel extends ChangeNotifier {
  SignupViewModel(this._service);
  final SignUpService _service;

  SubmitStatus submitStatus = SubmitStatus.idle;
  int? createdMemberId;
  String? passwordErrorText;
  String? snackbarMessage;

  void onPasswordChanged() {
    passwordErrorText = null;
    notifyListeners();
  }

  Future<void> submit(CreateMemberRequest request) async {
    if (submitStatus == SubmitStatus.submitting) return;
    submitStatus = SubmitStatus.submitting;
    createdMemberId = null;
    passwordErrorText = null;
    snackbarMessage = null;
    notifyListeners();

    try {
      final response = await _service.signUp(request);
      final id = response.result?.memberId;
      if (id == null) {
        throw StateError('회원가입 결과에 memberId가 없습니다.');
      }
      createdMemberId = id;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      submitStatus = SubmitStatus.error;
      final message = writeSignUpErrorMessage(error);
      if (error.response?.statusCode == 400 && message.contains('비밀번호')) {
        passwordErrorText = message;
      } else {
        snackbarMessage = message;
      }
    } on StateError {
      submitStatus = SubmitStatus.error;
      snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청전에 서버 상태를 확인해 주세요.';
    }
    if (!_disposed) notifyListeners(); // 요청 중 화면을 벗어났으면 반영하지 않습니다.
  }

  CheckStatus nicknameCheckStatus = CheckStatus.idle;
  String? nicknameErrorText;
  String? _duplicatedNickname;
  String _currentNickname = '';
  int _nicknameRequestVersion = 0;

  CheckStatus emailCheckStatus = CheckStatus.idle;
  String? emailErrorText;
  String? _duplicatedEmail;
  String _currentEmail = '';
  int _emailRequestVersion = 0;

  bool _disposed = false;

  bool get canCheckNickname =>
      nicknameCheckStatus != CheckStatus.checking &&
      nicknameCheckStatus != CheckStatus.duplicated;

  bool get canCheckEmail =>
      emailCheckStatus != CheckStatus.checking &&
      emailCheckStatus != CheckStatus.duplicated;

  void onNicknameChanged(String value) {
    final trimmed = value.trim();
    _currentNickname = trimmed;
    snackbarMessage = null; // 이전 서버 오류도 함께 무효화합니다.
    _nicknameRequestVersion++; // 이전 요청의 응답을 무효화합니다.
    if (_duplicatedNickname != null && trimmed == _duplicatedNickname) {
      nicknameCheckStatus = CheckStatus.duplicated;
      nicknameErrorText = '이미 사용중인 닉네임입니다.';
    } else {
      nicknameCheckStatus = CheckStatus.idle;
      nicknameErrorText = null;
    }
    if (!_disposed) notifyListeners();
  }

  void onEmailChanged(String value) {
    final trimmed = value.trim();
    _currentEmail = trimmed;
    snackbarMessage = null;
    _emailRequestVersion++;
    if (_duplicatedEmail != null && trimmed == _duplicatedEmail) {
      emailCheckStatus = CheckStatus.duplicated;
      emailErrorText = '이미 사용중인 이메일입니다.';
    } else {
      emailCheckStatus = CheckStatus.idle;
      emailErrorText = null;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> checkNickName(String value) async {
    final requested = value.trim();
    if (requested.isEmpty ||
        requested != _currentNickname ||
        !canCheckNickname) {
      return;
    }

    final version = ++_nicknameRequestVersion;
    nicknameCheckStatus = CheckStatus.checking;
    nicknameErrorText = null;
    notifyListeners();

    try {
      final available = await _service.checkNickName(requested);
      if (_disposed ||
          version != _nicknameRequestVersion ||
          _currentNickname != requested) {
        return;
      }
      nicknameCheckStatus = available
          ? CheckStatus.available
          : CheckStatus.duplicated;
      nicknameErrorText = available ? null : '이미 사용중인 닉네임입니다.';
      if (!available) _duplicatedNickname = requested;
    } on DioException {
      if (_disposed ||
          version != _nicknameRequestVersion ||
          _currentNickname != requested) {
        return;
      }
      nicknameCheckStatus = CheckStatus.error;
      nicknameErrorText = '중복 확인에 실패했습니다. 다시 시도하세요.';
    }
    if (!_disposed && version == _nicknameRequestVersion) notifyListeners();
  }

  Future<void> checkEmail(String value) async {
    final requested = value.trim();
    if (requested.isEmpty || requested != _currentEmail || !canCheckEmail) {
      return;
    }

    final version = ++_emailRequestVersion;
    emailCheckStatus = CheckStatus.checking;
    emailErrorText = null;
    notifyListeners();

    try {
      final available = await _service.checkEmail(requested);
      if (_disposed ||
          version != _emailRequestVersion ||
          _currentEmail != requested) {
        return;
      }
      emailCheckStatus = available
          ? CheckStatus.available
          : CheckStatus.duplicated;
      emailErrorText = available ? null : '이미 사용중인 이메일입니다.';
      if (!available) _duplicatedEmail = requested;
    } on DioException {
      if (_disposed ||
          version != _emailRequestVersion ||
          _currentEmail != requested) {
        return;
      }
      emailCheckStatus = CheckStatus.error;
      emailErrorText = '중복 확인에 실패했습니다. 다시 시도하세요.';
    }
    if (!_disposed && version == _emailRequestVersion) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _nicknameRequestVersion++;
    _emailRequestVersion++;
    super.dispose();
  }
}
