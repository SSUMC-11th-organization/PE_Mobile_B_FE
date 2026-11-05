import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/services/member_check_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
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
          context.read<MemberCheckService>(),
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

    return nickname.length >= 2 &&
        email.contains('@') &&
        password.length >= 8 &&
        _agreedToTerms &&
        viewModel.nicknameCheckStatus == CheckStatus.available &&
        viewModel.emailCheckStatus == CheckStatus.available;
  }

  void _onSubmit() {
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
    // 6주차 워크북 안내: 실제 회원가입 POST는 v6부터이므로 유효하면 홈으로 이동
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('회원가입이 완료되었습니다! (v5 모의 완료)')),
    );
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SignUpViewModel>(
      builder: (context, viewModel, child) {
        final canSubmit = _canSubmit(viewModel);

        return Scaffold(
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
                              if (nickname.length < 2) {
                                return '닉네임은 두 글자 이상 입력해 주세요.';
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
                              if (!email.contains('@')) {
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
                        hintText: '8자 이상 입력',
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
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        final password = value?.trim() ?? '';
                        if (password.length < 8) {
                          return '비밀번호를 8자 이상 입력해 주세요.';
                        }
                        return null;
                      },
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
                      onPressed: canSubmit ? _onSubmit : null,
                    ),

                    const SizedBox(height: 32),

                    // 6. [스터디 인증용] MovieLogButton 너비 3종 비교 섹션
                    const _MovieLogButtonWidthDemo(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// [미션 인증용] MovieLogButton의 너비 옵션(null / 고정값 / double.infinity) 비교 영역
class _MovieLogButtonWidthDemo extends StatelessWidget {
  const _MovieLogButtonWidthDemo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MovieLogButton 너비 비교 (미션 인증)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.violet,
            ),
          ),
          const SizedBox(height: 12),
          const Text('1. width: null (내용 기반 Intrinsic 크기)',
              style: TextStyle(fontSize: 12, color: AppColors.gray)),
          const SizedBox(height: 6),
          MovieLogButton(
            label: '너비 null 버튼',
            onPressed: () {},
          ),
          const SizedBox(height: 12),
          const Text('2. width: 140 (고정 너비)',
              style: TextStyle(fontSize: 12, color: AppColors.gray)),
          const SizedBox(height: 6),
          MovieLogButton(
            label: '너비 140 버튼',
            width: 140,
            onPressed: () {},
          ),
          const SizedBox(height: 12),
          const Text('3. width: double.infinity (전체 너비)',
              style: TextStyle(fontSize: 12, color: AppColors.gray)),
          const SizedBox(height: 6),
          MovieLogButton(
            label: '전체 너비 버튼',
            width: double.infinity,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
