import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:jay/storage/saved_email_storage.dart';
import 'package:jay/view_models/auth_view_model.dart';
import 'package:jay/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final AuthViewModel _auth;
  late final SavedEmailStorage _savedEmail;
  bool _rememberEmail = false;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthViewModel>();
    _savedEmail = context.read<SavedEmailStorage>();
    _auth.addListener(_showSessionExpired);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSessionExpired());
    _loadSavedEmail();
  }

  // Challenge: 저장해 둔 이메일이 있으면 채우고 체크박스를 켭니다.
  Future<void> _loadSavedEmail() async {
    try {
      final saved = await _savedEmail.read();
      if (!mounted || saved == null || saved.isEmpty) return;
      setState(() {
        _rememberEmail = true;
        if (_email.text.isEmpty) _email.text = saved;
      });
    } catch (_) {
      // 비민감 편의 기능이므로 읽기에 실패해도 로그인은 계속할 수 있습니다.
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    // 이메일만 저장합니다. 비밀번호·토큰은 SharedPreferences에 저장하지 않습니다.
    try {
      if (_rememberEmail) {
        await _savedEmail.save(email);
      } else {
        await _savedEmail.clear();
      }
    } catch (_) {}
    if (!mounted) return;
    _auth.login(email, _password.text);
  }

  void _showSessionExpired() {
    if (!mounted || !_auth.sessionExpired) return;
    _auth.consumeSessionExpired();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('로그인이 만료됐어요. 다시 로그인해 주세요.')));
  }

  @override
  void dispose() {
    _auth.removeListener(_showSessionExpired);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final loading = auth.status == AuthStatus.authenticating;
    final enabled = !loading && !auth.storageCleanUpInProgress;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('로그인'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 64),
              SvgPicture.asset(
                'assets/logos/movielog_logo.svg',
                width: 84,
                height: 84,
              ),
              const SizedBox(height: 24),
              const Text('MovieLog에 로그인'),
              const SizedBox(height: 48),
              TextFormField(
                controller: _email,
                enabled: enabled,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '이메일'),
                validator: (value) =>
                    (value?.trim().isEmpty ?? true) ? '이메일을 입력해 주세요.' : null,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _password,
                enabled: enabled,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호'),
                validator: (value) =>
                    (value?.isEmpty ?? true) ? '비밀번호를 입력해 주세요.' : null,
              ),
              if (auth.message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    auth.message!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Challenge: 이메일 저장 체크박스
              CheckboxListTile(
                value: _rememberEmail,
                onChanged: enabled
                    ? (value) => setState(() => _rememberEmail = value ?? false)
                    : null,
                title: const Text('이메일 저장'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 32),
              MovieLogButton(
                label: '로그인',
                width: double.infinity,
                isLoading: loading,
                onPressed: enabled ? _submit : null,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: enabled ? () => context.push('/register') : null,
                child: const Text('회원가입'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
