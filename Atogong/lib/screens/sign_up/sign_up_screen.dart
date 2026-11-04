import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../view_models/sign_up_view_model.dart';
import '../../widgets/movielog_button.dart';
import '../../widgets/movielog_text_form_field.dart';
import 'widgets/login_link.dart';
import 'widgets/terms_checkbox.dart';

/// 회원가입 Form. 형식 검사는 validator(2주차), 서버 중복 확인은 SignUpViewModel(6주차)
/// 회원가입 POST는 v5에 없어 이번 주차는 모양만 완성하고 홈으로 이동
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _agreedToTerms = false;

  static final _emailRegExp = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  // 버튼 활성화용 빠른 조건
  bool get _isNicknameValid => _nicknameController.text.trim().length >= 2;
  bool get _isEmailValid => _emailRegExp.hasMatch(_emailController.text.trim());
  bool get _isPasswordValid => _passwordController.text.length >= 8;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    final nickname = _nicknameController.text.trim();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$nickname님, 가입을 환영합니다!')));
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        return Scaffold(
          appBar: isWide
              ? null
              : AppBar(
                  title: Text('회원가입', style: TextStyle(color: colors.primary)),
                  centerTitle: true,
                ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 560 : double.infinity,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Form(
                    key: _formKey,
                    // 중복 확인 상태가 바뀔 때마다 Form 전체를 다시 그림
                    child: Consumer<SignUpViewModel>(
                      builder: (context, viewModel, child) {
                        // 형식 통과 + 두 중복 확인 모두 사용 가능 + 약관 동의
                        final canSubmit =
                            _isNicknameValid &&
                            _isEmailValid &&
                            _isPasswordValid &&
                            _agreedToTerms &&
                            viewModel.nicknameCheckStatus ==
                                CheckStatus.available &&
                            viewModel.emailCheckStatus == CheckStatus.available;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: isWide ? 80 : 24),
                            if (isWide) ...[
                              Text(
                                '회원가입',
                                textAlign: TextAlign.center,
                                style: textTheme.headlineMedium?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Text(
                              isWide
                                  ? 'MovieLog에 오신 것을 환영합니다!'
                                  : '환영합니다!\n간단한 정보만 입력하고 시작해보세요.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 48),
                            // 닉네임: 입력창과 중복 확인 버튼을 Row의 형제로, 8px 간격
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: MovieLogTextFormField(
                                    label: '닉네임',
                                    hint: '닉네임을 입력해주세요',
                                    controller: _nicknameController,
                                    isValid: _isNicknameValid,
                                    errorText: viewModel.nicknameErrorText,
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      final nickname = value?.trim() ?? '';
                                      if (nickname.isEmpty) {
                                        return '닉네임을 입력해주세요.';
                                      }
                                      if (nickname.length < 2) {
                                        return '닉네임은 2자 이상이어야 합니다.';
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      viewModel.onNicknameChanged(value);
                                      setState(() {});
                                    },
                                    onFieldSubmitted: (_) =>
                                        _emailFocusNode.requestFocus(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 라벨 높이만큼 내려 입력창과 나란히. width 미지정 → 내용 크기
                                Padding(
                                  padding: const EdgeInsets.only(top: 36),
                                  child: MovieLogButton(
                                    label: '중복 확인',
                                    isLoading:
                                        viewModel.nicknameCheckStatus ==
                                        CheckStatus.checking,
                                    onPressed:
                                        _isNicknameValid &&
                                            viewModel.canCheckNickname
                                        ? () => viewModel.checkNickname(
                                            _nicknameController.text,
                                          )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            if (viewModel.nicknameCheckStatus ==
                                CheckStatus.available)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '사용할 수 있는 닉네임입니다.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            // 이메일: 닉네임과 같은 구조
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: MovieLogTextFormField(
                                    label: '이메일',
                                    hint: '이메일 주소를 입력해주세요',
                                    controller: _emailController,
                                    focusNode: _emailFocusNode,
                                    isValid: _isEmailValid,
                                    errorText: viewModel.emailErrorText,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      final email = value?.trim() ?? '';
                                      if (email.isEmpty) {
                                        return '이메일을 입력해주세요.';
                                      }
                                      if (!_emailRegExp.hasMatch(email)) {
                                        return '올바른 이메일 형식이 아닙니다.';
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      viewModel.onEmailChanged(value);
                                      setState(() {});
                                    },
                                    onFieldSubmitted: (_) =>
                                        _passwordFocusNode.requestFocus(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(top: 36),
                                  child: MovieLogButton(
                                    label: '중복 확인',
                                    isLoading:
                                        viewModel.emailCheckStatus ==
                                        CheckStatus.checking,
                                    onPressed:
                                        _isEmailValid && viewModel.canCheckEmail
                                        ? () => viewModel.checkEmail(
                                            _emailController.text,
                                          )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            if (viewModel.emailCheckStatus ==
                                CheckStatus.available)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '사용할 수 있는 이메일입니다.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            MovieLogTextFormField(
                              label: '비밀번호',
                              hint: '비밀번호를 입력해주세요',
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              isValid: _isPasswordValid,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                              validator: (value) {
                                final password = value ?? '';
                                if (password.isEmpty) {
                                  return '비밀번호를 입력해주세요.';
                                }
                                if (password.length < 8) {
                                  return '비밀번호는 8자 이상이어야 합니다.';
                                }
                                return null;
                              },
                              onChanged: (_) => setState(() {}),
                              onFieldSubmitted: (_) {
                                if (canSubmit) _submit();
                              },
                            ),
                            const SizedBox(height: 40),
                            TermsCheckbox(
                              value: _agreedToTerms,
                              onChanged: (value) =>
                                  setState(() => _agreedToTerms = value),
                            ),
                            const SizedBox(height: 16),
                            // Form 하단 버튼: 부모 최대 너비
                            MovieLogButton(
                              label: '가입하기',
                              width: double.infinity,
                              onPressed: canSubmit ? _submit : null,
                            ),
                            const SizedBox(height: 16),
                            const LoginLink(),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
