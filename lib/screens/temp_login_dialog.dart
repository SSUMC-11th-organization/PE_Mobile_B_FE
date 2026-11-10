import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/services/rating_api_service.dart';
import '../view_models/learning_member_session.dart';
import '../widgets/movielog_button.dart';

/// 임시 로그인: 이미 가입한 memberId를 입력해 학습용 세션에 설정합니다. (인증 아님)
/// 서버에 해당 회원이 있는지 평점 조회(GET)로만 확인합니다.
Future<void> showTempLoginDialog(BuildContext context) async {
  final lastId = await LearningMemberSession.loadLastMemberId();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TempLoginDialog(initialId: lastId),
  );
}

class _TempLoginDialog extends StatefulWidget {
  const _TempLoginDialog({this.initialId});

  final int? initialId;

  @override
  State<_TempLoginDialog> createState() => _TempLoginDialogState();
}

class _TempLoginDialogState extends State<_TempLoginDialog> {
  late final _controller =
      TextEditingController(text: widget.initialId?.toString() ?? '');
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final id = int.tryParse(_controller.text.trim());
    if (id == null || id < 1) {
      setState(() => _errorText = 'memberId는 1 이상의 숫자로 입력해 주세요.');
      return;
    }
    final service = context.read<RatingApiService>();
    final session = context.read<LearningMemberSession>();
    final router = GoRouter.of(context);
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      await service.fetchMyRatings(id); // 존재하는 회원인지 확인 (404면 실패)
      if (!mounted) return;
      session.setMemberId(id);
      Navigator.pop(context);
      router.go('/movies');
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = writeMyRatingsErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_loading,
      child: AlertDialog(
        title: const Text('임시 로그인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '회원가입 때 받은 memberId를 입력하세요.\n(인증이 아닌 학습용 설정입니다)',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_loading,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'memberId',
                errorText: _errorText,
              ),
              onSubmitted: (_) => _loading ? null : _login(),
            ),
          ],
        ),
        actions: [
          MovieLogButton(
            label: '취소',
            onPressed: _loading ? null : () => Navigator.pop(context),
          ),
          MovieLogButton(
            label: '로그인',
            isLoading: _loading,
            onPressed: _login,
          ),
        ],
      ),
    );
  }
}
