import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../../theme/app_colors.dart';

/// 7주차: 서버 score가 1~5 정수라 반 점 입력을 끄고 별 한 개 단위로만 선택.
/// RatingBar가 항상 double을 돌려주므로 타입은 double 그대로 (1.0, 2.0 …)
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.enabled = true,
  });

  final double rating;
  final ValueChanged<double> onChanged;
  final bool enabled; // 저장 중에는 false로 두어 별점 변경을 막음

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating,
      minRating: 1,
      allowHalfRating: false,
      ignoreGestures: !enabled,
      itemCount: 5,
      itemSize: 40,
      itemBuilder: (context, index) =>
          const Icon(Icons.star, color: AppColors.violet),
      onRatingUpdate: onChanged,
    );
  }
}
