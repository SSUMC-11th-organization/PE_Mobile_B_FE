import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/profile_edit_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';

// 프로필 수정(/my/profile/edit) — email은 읽기 전용, nickname만 편집
// ProfileEditViewModel은 라우트(app_router.dart)에서 생성해 넘겨줌
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameController;
  late final String _originalNickname;

  @override
  void initState() {
    super.initState();
    _originalNickname = context.read<AuthViewModel>().member?.nickname ?? '';
    _nicknameController = TextEditingController(text: _originalNickname);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/my');
    }
  }

  Future<void> _onSave(ProfileEditViewModel vm) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final saved = await vm.save(_nicknameController.text);
    if (!mounted || !saved) return; // 실패 시 입력값 유지
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('닉네임을 변경했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    _close(); // 마이페이지는 AuthViewModel.member를 보고 있어 바로 반영됨
  }

  @override
  Widget build(BuildContext context) {
    final member = context.watch<AuthViewModel>().member;
    final vm = context.watch<ProfileEditViewModel>();
    final saving = vm.isSaving;
    final changed = _nicknameController.text.trim() != _originalNickname;

    return PopScope(
      canPop: !saving, // 저장 중에는 뒤로가기 막음
      child: Scaffold(
        appBar: CommonAppBar(
          title: '프로필 수정',
          onBack: saving ? null : _close,
        ),
        body: SafeArea(
          child: member == null
              ? const Center(child: Text('내 정보를 불러온 뒤 수정할 수 있습니다.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          initialValue: member.email,
                          readOnly: true,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: '이메일',
                            helperText: '이메일은 변경할 수 없습니다.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nicknameController,
                          readOnly: saving, // 저장 중 입력 잠금
                          maxLength: ProfileEditViewModel.maxLength,
                          decoration: InputDecoration(
                            labelText: '닉네임',
                            hintText:
                                '${ProfileEditViewModel.minLength}~${ProfileEditViewModel.maxLength}자',
                            errorText: vm.fieldError,
                          ),
                          textInputAction: TextInputAction.done,
                          validator: ProfileEditViewModel.validateNickname,
                          onChanged: (_) {
                            vm.onNicknameChanged();
                            setState(() {}); // 저장 버튼 활성 상태 갱신
                          },
                          onFieldSubmitted: (_) {
                            if (!saving && changed) _onSave(vm);
                          },
                        ),
                        if (vm.generalError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            vm.generalError!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ],
                        const SizedBox(height: 24),
                        MovieLogButton(
                          // 네트워크 실패 등 일반 오류 뒤에는 같은 버튼으로 재시도
                          label: vm.generalError != null ? '다시 저장' : '저장',
                          width: double.infinity,
                          isLoading: saving, // 저장 중 버튼 잠금
                          onPressed: changed ? () => _onSave(vm) : null,
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
