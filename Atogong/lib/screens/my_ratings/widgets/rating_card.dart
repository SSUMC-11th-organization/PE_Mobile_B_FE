import 'package:flutter/material.dart';

import '../../../data/models/rating_with_movie.dart';
import '../../../widgets/tmdb_poster_image.dart';

/// 평점 한 건. 영화 정보(TMDB)를 못 찾았으면 제목·포스터만 placeholder, 평점 기록은 유지
class RatingCard extends StatelessWidget {
  const RatingCard({
    super.key,
    required this.entry,
    this.onEdit,
    this.onDelete,
  });

  final RatingWithMovie entry;
  final VoidCallback? onEdit; // 7주차: 카드 오른쪽 개별 수정·삭제 버튼
  final VoidCallback? onDelete;

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}.$month.$day';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final rating = entry.rating;
    final movie = entry.movie;
    final comment = rating.comment;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TmdbPosterImage(
                posterPath: movie?.posterPath,
                width: 60,
                height: 90,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie?.title ?? '영화 정보 없음 (movieId ${rating.movieId})',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 18, color: colors.primary),
                      const SizedBox(width: 4),
                      Text('${rating.score}점', style: textTheme.bodyMedium),
                      const Spacer(),
                      Text(
                        _formatDate(rating.createdAt),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                  // comment가 null이면 표시하지 않음
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      comment,
                      style: textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (onEdit != null || onDelete != null)
              Column(
                children: [
                  if (onEdit != null)
                    IconButton(
                      tooltip: '수정',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEdit,
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: '삭제',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
