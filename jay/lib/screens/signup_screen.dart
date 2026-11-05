import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jay/widgets/common_app_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/signup_validators.dart';
import '../view_models/signup_view_model.dart';
import '../widgets/login_prompt.dart';
import '../widgets/movielog_button.dart';
import '../widgets/signup_text_field.dart';
import '../widgets/terms_checkbox.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const _screenPadding = 24.0;

  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _agreedToTerms = false;

  /// 버튼 활성화 조건. 각 입력창의 Validator와 같은 규칙을 사용합니다.
  bool get _canSubmit =>
      SignUpValidators.nickname(_nicknameController.text) == null &&
      SignUpValidators.email(_emailController.text) == null &&
      SignUpValidators.password(_passwordController.text) == null &&
      _agreedToTerms;

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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('회원가입 정보가 확인되었습니다.')));
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: '회원가입', centerTitle: true),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(_screenPadding),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              // 내용이 짧으면 약관·버튼을 화면 아래에 붙이고,
              // 키보드로 화면이 줄어들면 스크롤로 전환됩니다.
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(
                    0,
                    constraints.maxHeight - _screenPadding * 2,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '환영합니다!\n간단한 정보만 입력하고 시작해보세요.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: 32),
                        Consumer<SignupViewModel>(
                          builder: (context, viewModel, child) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _CheckableField(
                                  field: SignUpTextField(
                                    label: '닉네임',
                                    hintText: '닉네임을 입력해주세요',
                                    controller: _nicknameController,
                                    validator: SignUpValidators.nickname,
                                    errorText: viewModel.nicknameErrorText,
                                    textInputAction: TextInputAction.next,
                                    onChanged: (value) {
                                      viewModel.onNicknameChanged(value);
                                      setState(() {});
                                    },
                                    onFieldSubmitted: (_) =>
                                        _emailFocusNode.requestFocus(),
                                  ),
                                  button: MovielogButton(
                                    label: '중복 확인',
                                    isLoading:
                                        viewModel.nicknameCheckStatus ==
                                        CheckStatus.checking,
                                    onPressed: viewModel.canCheckNickname
                                        ? () => viewModel.checkNickName(
                                            _nicknameController.text,
                                          )
                                        : null,
                                  ),
                                ),
                                if (viewModel.nicknameCheckStatus ==
                                    CheckStatus.available)
                                  const _AvailableText('사용할 수 있는 닉네임입니다.'),
                                const SizedBox(height: 16),
                                _CheckableField(
                                  field: SignUpTextField(
                                    label: '이메일',
                                    hintText: '이메일 주소를 입력해주세요',
                                    controller: _emailController,
                                    focusNode: _emailFocusNode,
                                    validator: SignUpValidators.email,
                                    errorText: viewModel.emailErrorText,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    onChanged: (value) {
                                      viewModel.onEmailChanged(value);
                                      setState(() {});
                                    },
                                    onFieldSubmitted: (_) =>
                                        _passwordFocusNode.requestFocus(),
                                  ),
                                  button: MovielogButton(
                                    label: '중복 확인',
                                    isLoading:
                                        viewModel.emailCheckStatus ==
                                        CheckStatus.checking,
                                    onPressed: viewModel.canCheckEmail
                                        ? () => viewModel.checkEmail(
                                            _emailController.text,
                                          )
                                        : null,
                                  ),
                                ),
                                if (viewModel.emailCheckStatus ==
                                    CheckStatus.available)
                                  const _AvailableText('사용할 수 있는 이메일입니다.'),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        SignUpTextField(
                          label: '비밀번호',
                          hintText: '비밀번호를 입력해주세요',
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          validator: SignUpValidators.password,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          onFieldSubmitted: (_) =>
                              FocusScope.of(context).unfocus(),
                        ),
                        const Spacer(),
                        const SizedBox(height: 24),
                        TermsCheckbox(
                          value: _agreedToTerms,
                          onChanged: (agreed) =>
                              setState(() => _agreedToTerms = agreed),
                        ),
                        const SizedBox(height: 8),
                        MovielogButton(
                          label: '가입하기',
                          width: double.infinity,
                          onPressed: _canSubmit ? _submit : null,
                        ),
                        const SizedBox(height: 16),
                        // 로그인 화면이 아직 없으므로 동작은 연결하지 않습니다.
                        LoginPrompt(onLogin: () {}),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 입력창과 중복 확인 버튼을 나란히 배치합니다.
/// 버튼은 라벨을 제외한 입력창 높이에 맞춰 위쪽에 정렬합니다.
class _CheckableField extends StatelessWidget {
  const _CheckableField({required this.field, required this.button});

  static const _labelOffset = 27.0; // 라벨 Text + SizedBox(height: 8)

  final Widget field;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: _labelOffset + 4),
          child: button,
        ),
      ],
    );
  }
}

class _AvailableText extends StatelessWidget {
  const _AvailableText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
      ),
    );
  }
}
