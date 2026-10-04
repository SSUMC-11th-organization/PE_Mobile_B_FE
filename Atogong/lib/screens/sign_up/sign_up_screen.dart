import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/movielog_text_form_field.dart';
import 'widgets/login_link.dart';
import 'widgets/sign_up_button.dart';
import 'widgets/terms_checkbox.dart';

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
  bool get _canSubmit =>
      _isNicknameValid && _isEmailValid && _isPasswordValid && _agreedToTerms;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // 제출 시 Form 전체 재검증
  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_nicknameController.text.trim()}님, 가입을 환영합니다!'),
      ),
    );
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
                    child: Column(
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
                        MovieLogTextFormField(
                          label: '닉네임',
                          hint: '닉네임을 입력해주세요',
                          controller: _nicknameController,
                          isValid: _isNicknameValid,
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
                          onChanged: (_) => setState(() {}),
                          onFieldSubmitted: (_) =>
                              _emailFocusNode.requestFocus(),
                        ),
                        const SizedBox(height: 24),
                        MovieLogTextFormField(
                          label: '이메일',
                          hint: '이메일 주소를 입력해주세요',
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          isValid: _isEmailValid,
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
                          onChanged: (_) => setState(() {}),
                          onFieldSubmitted: (_) =>
                              _passwordFocusNode.requestFocus(),
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
                            if (_canSubmit) {
                              _submit();
                            }
                          },
                        ),
                        const SizedBox(height: 40),
                        TermsCheckbox(
                          value: _agreedToTerms,
                          onChanged: (value) =>
                              setState(() => _agreedToTerms = value),
                        ),
                        const SizedBox(height: 16),
                        SignUpButton(onPressed: _canSubmit ? _submit : null),
                        const SizedBox(height: 16),
                        const LoginLink(),
                      ],
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
