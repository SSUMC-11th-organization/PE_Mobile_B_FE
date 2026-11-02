import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/services/member_check_service.dart';

enum CheckStatus { idle, checking, available, duplicated, error }

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

// 회원가입 화면의 닉네임/이메일 중복 확인 상태 관리
class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service);

  final MemberCheckService _service;
  bool _disposed = false;
  final _nickname = _FieldCheck('이미 사용 중인 닉네임입니다.');
  final _email = _FieldCheck('이미 사용 중인 이메일입니다.');

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
    _notify();
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
