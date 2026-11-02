import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/services/member_check_service.dart';
import '../theme/app_text_styles.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/email_field.dart';
import '../widgets/movielog_button.dart';
import '../widgets/password_field.dart';
import '../widgets/terms_checkbox_row.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // 폼 검증 + 닉네임/이메일 중복 확인까지 통과해야 홈으로 이동 (회원가입 POST는 v5에 없어 보내지 않음)
  void _onSubmit(SignUpViewModel vm) {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || !vm.bothAvailable) return;
    FocusScope.of(context).unfocus();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = _nicknameController.text.trim().length >= 2 &&
        EmailField.pattern.hasMatch(_emailController.text.trim()) &&
        _passwordController.text.length >= 8 &&
        _agreedToTerms;

    // 화면에 들어올 때 SignUpViewModel을 만들고, 화면을 벗어나면 함께 dispose
    return ChangeNotifierProvider<SignUpViewModel>(
      create: (c) => SignUpViewModel(c.read<MemberCheckService>()),
      // canPop: false → 안드로이드 백 제스처 등 시스템 뒤로가기를 막음
      child: PopScope(
        canPop: false,
        child: Scaffold(
          // onBack을 넘기지 않음 → 회원가입 화면에는 뒤로가기 버튼이 없음
          appBar: const CommonAppBar(title: '회원가입'),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Consumer<SignUpViewModel>(
                      builder: (context, vm, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _nicknameController,
                                  decoration: InputDecoration(
                                    labelText: '닉네임',
                                    hintText: '두 글자 이상 입력',
                                    errorText: vm.nicknameErrorText,
                                    suffixIcon: vm.nicknameCheckStatus ==
                                            CheckStatus.available
                                        ? const Icon(Icons.check_circle)
                                        : null,
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    final nickname = value?.trim() ?? '';
                                    if (nickname.isEmpty) {
                                      return '닉네임을 입력해주세요.';
                                    }
                                    if (nickname.length < 2) {
                                      return '닉네임은 두 글자 이상 입력해주세요.';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    vm.onNicknameChanged(value);
                                    setState(() {});
                                  },
                                  onFieldSubmitted: (_) =>
                                      _emailFocusNode.requestFocus(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              MovieLogButton(
                                label: '중복 확인',
                                isLoading: vm.nicknameCheckStatus ==
                                    CheckStatus.checking,
                                onPressed: vm.canCheckNickname
                                    ? () => vm.checkNickname(
                                          _nicknameController.text,
                                        )
                                    : null,
                              ),
                            ],
                          ),
                          if (vm.nicknameCheckStatus == CheckStatus.available)
                            const Text(
                              '사용할 수 있는 닉네임입니다.',
                              style: AppTextStyles.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Consumer<SignUpViewModel>(
                      builder: (context, vm, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _emailController,
                                  focusNode: _emailFocusNode,
                                  decoration: InputDecoration(
                                    labelText: '이메일',
                                    errorText: vm.emailErrorText,
                                    suffixIcon: vm.emailCheckStatus ==
                                            CheckStatus.available
                                        ? const Icon(Icons.check_circle)
                                        : null,
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    if (email.isEmpty) {
                                      return '이메일을 입력해주세요.';
                                    }
                                    if (!EmailField.pattern.hasMatch(email)) {
                                      return '올바른 이메일 형식이 아니에요.';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    vm.onEmailChanged(value);
                                    setState(() {});
                                  },
                                  onFieldSubmitted: (_) =>
                                      _passwordFocusNode.requestFocus(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              MovieLogButton(
                                label: '중복 확인',
                                isLoading:
                                    vm.emailCheckStatus == CheckStatus.checking,
                                onPressed: vm.canCheckEmail
                                    ? () => vm.checkEmail(_emailController.text)
                                    : null,
                              ),
                            ],
                          ),
                          if (vm.emailCheckStatus == CheckStatus.available)
                            const Text(
                              '사용할 수 있는 이메일입니다.',
                              style: AppTextStyles.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TermsCheckboxRow(
                      value: _agreedToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreedToTerms = value ?? false;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Consumer<SignUpViewModel>(
                      builder: (context, vm, _) => MovieLogButton(
                        label: '가입하기',
                        width: double.infinity,
                        onPressed: canSubmit && vm.bothAvailable
                            ? () => _onSubmit(vm)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
