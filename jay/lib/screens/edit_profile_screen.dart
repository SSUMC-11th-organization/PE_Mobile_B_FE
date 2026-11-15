import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jay/view_models/auth_view_model.dart';
import 'package:jay/view_models/edit_profile_view_model.dart';
import 'package:jay/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _controller;
  late final String _initialNickname;

  /// 저장 성공 후 pop할 때는 변경 확인 Dialog를 띄우지 않기 위한 표시
  bool _leaving = false;

  bool get _isDirty => _controller.text.trim() != _initialNickname;

  @override
  void initState() {
    super.initState();
    _initialNickname = context.read<AuthViewModel>().member?.nickname ?? '';
    _controller = TextEditingController(text: _initialNickname);
    // 입력이 바뀔 때마다 PopScope.canPop을 다시 계산합니다.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final viewModel = context.read<EditProfileViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final success = await viewModel.save(_controller.text);
    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(const SnackBar(content: Text('프로필을 수정했어요.')));
      setState(() => _leaving = true);
      router.pop(); // 마이페이지로 돌아가면 새 닉네임이 이미 반영되어 있습니다.
    } else if (viewModel.message != null) {
      messenger.showSnackBar(SnackBar(content: Text(viewModel.message!)));
    }
  }

  /// Challenge: 변경 내용이 있을 때 뒤로가기 확인 Dialog
  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('변경 내용을 버릴까요?', textAlign: TextAlign.center),
        content: const Text('저장하지 않은 내용은 사라집니다.', textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('계속 수정'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _leaving = true);
    GoRouter.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthViewModel, String?>(
      (a) => a.member?.email,
    );

    return Consumer<EditProfileViewModel>(
      builder: (context, viewModel, child) {
        final saving = viewModel.status == EditProfileStatus.saving;
        return PopScope(
          // 저장 중에는 막고, 변경 내용이 있으면 확인 Dialog를 거칩니다.
          canPop: !saving && (_leaving || !_isDirty),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop || saving) return;
            _confirmDiscard();
          },
          child: Scaffold(
            appBar: AppBar(centerTitle: true, title: const Text('프로필 수정')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: email,
                    enabled: false, // email은 읽기 전용입니다.
                    decoration: const InputDecoration(
                      labelText: '이메일 (변경할 수 없습니다)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    enabled: !saving,
                    maxLength: 12,
                    decoration: InputDecoration(
                      labelText: '닉네임',
                      errorText: viewModel.nicknameError,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: MovieLogButton(
                      label: '저장',
                      isLoading: saving,
                      onPressed: saving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
