import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/movielog_button.dart';

/// MovieLogButton 너비 옵션 비교 화면 (디버그 화면에서 진입)
class ButtonWidthDemoScreen extends StatelessWidget {
  const ButtonWidthDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MovieLogButton 너비 비교')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: MovieLogButtonWidthDemo(),
      ),
    );
  }
}

/// [미션 인증용] MovieLogButton의 너비 옵션(null / 고정값 / double.infinity) 비교 영역
class MovieLogButtonWidthDemo extends StatelessWidget {
  const MovieLogButtonWidthDemo({super.key});

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
