import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 공용 버튼. 상태(기본·통신 중·비활성)를 표시만 하고 스스로 바꾸지 않음 — 결정은 ViewModel
/// width: null = 내용 크기(입력창 옆 보조 버튼), double.infinity = 부모 최대 너비(Form 하단), 고정값 = 항상 그 크기
class MovieLogButton extends StatelessWidget {
  const MovieLogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;

  // isLoading이면 onPressed와 관계없이 항상 비활성
  bool get _disabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 44,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          disabledBackgroundColor: AppColors.gray,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // 통신 중에는 label과 인디케이터를 동시에 그리지 않고 하나만
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
