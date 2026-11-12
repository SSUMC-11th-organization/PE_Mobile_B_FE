import 'package:flutter/material.dart';

import '../data/models/rating_request.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'movie_rating_input.dart';
import 'movielog_button.dart';

// 별점 + 코멘트 입력 다이얼로그 — 저장 성공 시 pop(true), 취소 시 pop(false)
// 실제 저장은 onSubmit이 담당하고, 실패하면 예외를 던져 다이얼로그에 문구를 표시
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    this.initialScore = 0,
    this.initialComment,
    required this.onSubmit,
  });

  final int initialScore; // 0이면 아직 별점 미선택
  final String? initialComment;
  final Future<void> Function(int score, String? comment) onSubmit;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  static const int _maxCommentLength = 500;

  late double _score;
  late final TextEditingController _commentController;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _score = widget.initialScore.toDouble();
    _commentController = TextEditingController(text: widget.initialComment);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_score <= 0 || _isSubmitting) return;
    final comment = _commentController.text.trim();
    if (comment.length > _maxCommentLength) {
      setState(() {
        _errorText = '코멘트는 $_maxCommentLength자 이하로 입력해 주세요.';
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await widget.onSubmit(
        validateServerScore(_score),
        comment.isEmpty ? null : comment,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on StateError catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('저장하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  // 실패 시 입력값은 그대로 두고 다시 제출할 수 있게 되돌림
  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorText = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: const Text('평점 남기기'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: MovieRatingInput(
                  rating: _score,
                  enabled: !_isSubmitting,
                  onChanged: (value) {
                    setState(() {
                      _score = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                enabled: !_isSubmitting,
                maxLines: 3,
                maxLength: _maxCommentLength,
                decoration: const InputDecoration(
                  hintText: '코멘트를 남겨보세요 (선택)',
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          MovieLogButton(
            label: '취소',
            onPressed:
                _isSubmitting ? null : () => Navigator.of(context).pop(false),
          ),
          MovieLogButton(
            label: '확인',
            isLoading: _isSubmitting,
            onPressed: _score > 0 && !_isSubmitting ? _submit : null,
          ),
        ],
      ),
    );
  }
}
