import 'package:flutter/material.dart';

class MovieListError extends StatelessWidget {
  const MovieListError({super.key, required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message; // 없으면 기본 문구

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(height: 12),
          Text(message ?? '영화를 불러오지 못했습니다.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
