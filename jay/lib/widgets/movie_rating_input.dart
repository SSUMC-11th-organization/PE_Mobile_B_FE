import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:jay/theme/app_colors.dart';

class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.enabled = true,
  });

  final double rating;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating,
      minRating: 1,
      allowHalfRating: false, // 7주차 서버 연동: 1~5 정수만 선택
      ignoreGestures: !enabled,
      itemCount: 5,
      itemSize: 40,
      itemBuilder: (context, index) =>
          const Icon(Icons.star, color: AppColors.violet),
      onRatingUpdate: onChanged,
    );
  }
}
