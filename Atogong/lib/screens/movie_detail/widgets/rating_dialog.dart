import 'package:flutter/material.dart';

import 'movie_rating_input.dart';

class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key, this.initialRating});

  final double? initialRating;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double _rating = widget.initialRating ?? 0;

  void _reset() => setState(() => _rating = 0);
  void _restore() => setState(() => _rating = widget.initialRating ?? 0);

  @override
  Widget build(BuildContext context) {
    final hasPrevious = widget.initialRating != null;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '영화는 어떠셨나요?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            // RatingBar가 initialRating 변경을 반영하도록 key 부여
            MovieRatingInput(
              key: ValueKey(_rating),
              rating: _rating,
              onChanged: (value) => setState(() => _rating = value),
            ),
            const SizedBox(height: 8),
            Text(_rating == 0 ? '별을 눌러 선택하세요' : '$_rating점'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _rating == 0 ? null : _reset,
                  child: const Text('초기화'),
                ),
                if (hasPrevious)
                  TextButton(
                    onPressed: _rating == widget.initialRating
                        ? null
                        : _restore,
                    child: const Text('다시 선택'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _rating == 0
                    ? null
                    : () => Navigator.pop(context, _rating),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
