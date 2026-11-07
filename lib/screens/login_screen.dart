import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/email_field.dart';
import '../widgets/movielog_button.dart';
import '../widgets/password_field.dart';

// 로그인(/login) — 성공하면 AuthStatus.signedIn → GoRouter redirect가 /home으로 이동
// 비밀번호는 TextEditingController에만 있고, 요청에 한 번 넘긴 뒤 어디에도 저장하지 않음
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onSubmit(AuthViewModel auth) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await auth.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  void _onChanged(AuthViewModel auth) {
    auth.clearLoginError();
    setState(() {}); // 버튼 활성 상태 갱신
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final busy = auth.isAuthenticating;
    final canSubmit =
        EmailField.pattern.hasMatch(_emailController.text.trim()) &&
            _passwordController.text.isNotEmpty;
    final error = auth.loginErrorMessage;
    final notice = auth.signedOutNotice;

    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: const CommonAppBar(title: '로그인'),
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
                  if (notice != null) ...[
                    Text(notice, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                  ],
                  AbsorbPointer(
                    absorbing: busy, // 통신 중 입력 잠금
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EmailField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          nextFocus: _passwordFocusNode,
                          onChanged: (_) => _onChanged(auth),
                        ),
                        const SizedBox(height: 16),
                        PasswordField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          onChanged: (_) => _onChanged(auth),
                        ),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error, style: const TextStyle(color: AppColors.error)),
                  ],
                  const SizedBox(height: 24),
                  MovieLogButton(
                    label: '로그인',
                    width: double.infinity,
                    isLoading: busy, // 통신 중 비활성화
                    onPressed: canSubmit ? () => _onSubmit(auth) : null,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    // push — 회원가입 화면에서 뒤로가기로 로그인 화면에 돌아올 수 있게
                    onPressed: busy ? null : () => context.push('/register'),
                    child: const Text('아직 회원이 아니신가요? 회원가입'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
