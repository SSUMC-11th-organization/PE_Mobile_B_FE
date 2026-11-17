import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/create_member_request.dart';
import '../data/services/sign_up_service.dart';
import '../theme/app_text_styles.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 상위에서 SignUpViewModel이 제공되지 않은 경우 기본 생성
    try {
      context.read<SignUpViewModel>();
      return const _SignUpFormView();
    } catch (_) {
      return ChangeNotifierProvider<SignUpViewModel>(
        create: (context) => SignUpViewModel(
          context.read<SignUpService>(),
        ),
        child: const _SignUpFormView(),
      );
    }
  }
}

class _SignUpFormView extends StatefulWidget {
  const _SignUpFormView();

  @override
  State<_SignUpFormView> createState() => _SignUpFormViewState();
}

class _SignUpFormViewState extends State<_SignUpFormView> {
  final _formKey = GlobalKey<FormState>();

  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _agreedToTerms = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool _canSubmit(SignUpViewModel viewModel) {
    final nickname = _nicknameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    return viewModel.submitStatus != SubmitStatus.submitting &&
        nickname.length >= 2 &&
        email.contains('@') &&
        password.length >= 8 &&
        _agreedToTerms &&
        viewModel.nicknameCheckStatus == CheckStatus.available &&
        viewModel.emailCheckStatus == CheckStatus.available;
  }

  Future<void> _onSubmit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    final viewModel = context.read<SignUpViewModel>();

    if (!isValid || !_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입력값과 약관 동의를 다시 확인해 주세요.')),
      );
      return;
    }

    if (viewModel.nicknameCheckStatus != CheckStatus.available ||
        viewModel.emailCheckStatus != CheckStatus.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임과 이메일 중복 확인을 완료해 주세요.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    await viewModel.submit(CreateMemberRequest(
      email: _emailController.text,
      password: _passwordController.text,
      nickname: _nicknameController.text,
    ));
    if (!mounted) return;

    final memberId = viewModel.createdMemberId;
    if (viewModel.submitStatus == SubmitStatus.success && memberId != null) {
      context.read<LearningMemberSession>().setMemberId(memberId);
      context.go('/movies');
      return;
    }
    // 비밀번호 400은 errorText로 이미 표시됩니다. 나머지(400·409)는 Snackbar.
    _formKey.currentState?.validate();
    final message = viewModel.snackbarMessage;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SignUpViewModel>(
      builder: (context, viewModel, child) {
        final canSubmit = _canSubmit(viewModel);

        return PopScope(
          // 제출 중에는 뒤로가기·스와이프 백을 막습니다.
          canPop: viewModel.submitStatus != SubmitStatus.submitting,
          child: Scaffold(
          appBar: const CommonAppBar(title: '회원가입', centerTitle: true),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. 닉네임 입력란 + 중복 확인 버튼
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nicknameController,
                            decoration: InputDecoration(
                              labelText: '닉네임',
                              hintText: '두 글자 이상 입력',
                              errorText: viewModel.nicknameErrorText,
                            ),
                            textInputAction: TextInputAction.next,
                            onChanged: (val) {
                              viewModel.onNicknameChanged(val);
                              setState(() {});
                            },
                            onFieldSubmitted: (_) =>
                                _emailFocusNode.requestFocus(),
                            validator: (value) {
                              final nickname = value?.trim() ?? '';
                              if (nickname.isEmpty) {
                                return '닉네임을 입력해 주세요.';
                              }
                              if (nickname.length < 2 || nickname.length > 12) {
                                return '닉네임은 2~12자로 입력해 주세요.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: MovieLogButton(
                            label: '중복 확인',
                            isLoading: viewModel.nicknameCheckStatus ==
                                CheckStatus.checking,
                            onPressed: viewModel.canCheckNickname
                                ? () => viewModel
                                    .checkNickname(_nicknameController.text)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    if (viewModel.nicknameCheckStatus == CheckStatus.available)
                      const Padding(
                        padding: EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          '✓ 사용할 수 있는 닉네임입니다.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // 2. 이메일 입력란 + 중복 확인 버튼
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            decoration: InputDecoration(
                              labelText: '이메일',
                              hintText: 'example@domain.com',
                              errorText: viewModel.emailErrorText,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onChanged: (val) {
                              viewModel.onEmailChanged(val);
                              setState(() {});
                            },
                            onFieldSubmitted: (_) =>
                                _passwordFocusNode.requestFocus(),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) {
                                return '이메일을 입력해 주세요.';
                              }
                              if (!_emailPattern.hasMatch(email)) {
                                return '올바른 이메일 형식이 아니에요.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: MovieLogButton(
                            label: '중복 확인',
                            isLoading: viewModel.emailCheckStatus ==
                                CheckStatus.checking,
                            onPressed: viewModel.canCheckEmail
                                ? () => viewModel
                                    .checkEmail(_emailController.text)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    if (viewModel.emailCheckStatus == CheckStatus.available)
                      const Padding(
                        padding: EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          '✓ 사용할 수 있는 이메일입니다.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // 3. 비밀번호 입력란
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        hintText: '8자 이상, 대·소문자·숫자·특수문자',
                        // 서버 400(비밀번호 형식)은 로컬 validator 통과 후에도 유지됩니다.
                        errorText: viewModel.passwordErrorText,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        viewModel.onPasswordChanged();
                        setState(() {});
                      },
                      validator: validatePasswordFormat,
                    ),
                    const SizedBox(height: 20),

                    // 4. 약관 동의 체크박스
                    Row(
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          onChanged: (value) {
                            setState(() {
                              _agreedToTerms = value ?? false;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            '필수 약관에 동의합니다',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 5. Form 하단 가입하기 버튼 (MovieLogButton 전체 너비: width double.infinity)
                    MovieLogButton(
                      label: '가입하기',
                      width: double.infinity,
                      isLoading:
                          viewModel.submitStatus == SubmitStatus.submitting,
                      onPressed: canSubmit ? _onSubmit : null,
                    ),
                  ],
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

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// 8자 이상, 소문자·대문자·숫자·특수문자(!@#$%^&*) 각 1개 이상. 서버 검증을 대체하지 않습니다.
String? validatePasswordFormat(String? value) {
  final password = value ?? '';
  if (password.length < 8 ||
      !password.contains(RegExp(r'[a-z]')) ||
      !password.contains(RegExp(r'[A-Z]')) ||
      !password.contains(RegExp(r'[0-9]')) ||
      !password.contains(RegExp(r'[!@#$%^&*]'))) {
    return '8자 이상, 대·소문자·숫자·특수문자(!@#\$%^&*)를 포함해 주세요.';
  }
  return null;
}
