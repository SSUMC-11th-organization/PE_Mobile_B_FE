import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../../models/movie.dart';

class MovieInfoSection extends StatelessWidget {
  const MovieInfoSection({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          movie.title,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${movie.year} · ${movie.genre} · ${movie.runtime}분',
          style: textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            RatingBarIndicator(
              rating: movie.rating,
              itemCount: 5,
              itemSize: 22,
              itemBuilder: (context, _) => Icon(
                Icons.star,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${movie.rating}',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Text('(${movie.ratingCount})', style: textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [for (final tag in movie.tags) Chip(label: Text(tag))],
        ),
        const Divider(height: 40),
        Text(
          '시놉시스',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(movie.synopsis, style: textTheme.bodyLarge?.copyWith(height: 1.6)),
      ],
    );
  }
}
