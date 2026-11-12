import 'package:flutter/material.dart';

import '../../../data/models/rating_request.dart';
import '../../../widgets/movielog_button.dart';
import 'movie_rating_input.dart';

/// 평점 등록·수정 공용 Dialog. 저장 로직은 onSubmit으로 받아 Dialog 안에서 실행하고,
/// 저장 중 상태를 Dialog가 직접 관리해 중복 탭과 이탈을 막음.
/// 반환값: 저장 성공 true / 취소 false (취소 시 onSubmit을 호출하지 않아 API 요청도 없음)
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    this.initialScore = 0,
    this.initialComment,
    required this.onSubmit,
  });

  final int initialScore; // 수정일 때 기존 별점. 등록은 0(미선택)
  final String? initialComment; // null이면 TextField가 빈 칸으로 시작
  final Future<void> Function(int score, String? comment) onSubmit;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late int _score = widget.initialScore;
  // build 안에서 만들면 setState마다 새로 생겨 입력이 초기화되므로 State에서 한 번만 생성
  late final _commentController = TextEditingController(
    text: widget.initialComment ?? '',
  );
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PopScope는 시스템 뒤로가기만 막음. 바깥 탭은 showDialog의 barrierDismissible: false로 함께 막음
    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: const Text('평점을 남겨주세요'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MovieRatingInput(
                rating: _score.toDouble(),
                enabled: !_isSubmitting,
                onChanged: (value) =>
                    setState(() => _score = validateServerScore(value)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                maxLines: 3,
                maxLength: 500,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(hintText: '코멘트를 남겨보세요 (선택)'),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(_errorText!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
        actions: [
          MovieLogButton(
            label: '취소',
            onPressed: _isSubmitting
                ? null
                : () => Navigator.pop(context, false),
          ),
          // 별점을 선택해야(_score > 0) 활성화. 저장 중에는 회색 + 인디케이터
          MovieLogButton(
            label: '확인',
            isLoading: _isSubmitting,
            onPressed: _score > 0 && !_isSubmitting ? _onConfirm : null,
          ),
        ],
      ),
    );
  }

  Future<void> _onConfirm() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final trimmed = _commentController.text.trim();
    if (trimmed.length > 500) {
      setState(() {
        _isSubmitting = false;
        _errorText = '코멘트는 500자 이하로 입력해 주세요.';
      });
      return;
    }
    try {
      // 빈 문자열은 null로 바꿔 요청
      await widget.onSubmit(_score, trimmed.isEmpty ? null : trimmed);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      // 실패해도 입력(별점·코멘트)은 그대로 두고 버튼만 되돌려 다시 시도할 수 있게 함
      setState(() {
        _isSubmitting = false;
        // 호출부가 StateError로 넘긴 서버 message(400/403/404/409)는 그대로 표시
        _errorText = error is StateError
            ? error.message
            : '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }
}
