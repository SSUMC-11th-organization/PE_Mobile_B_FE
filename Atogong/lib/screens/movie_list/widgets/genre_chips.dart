import 'package:flutter/material.dart';

import '../../../data/models/tmdb_genre_dto.dart';

class GenreChips extends StatelessWidget {
  const GenreChips({
    super.key,
    required this.genres,
    required this.selectedId,
    required this.onSelected,
    this.enabled = true,
  });

  final List<TmdbGenreDto> genres; // Genre API로 받은 id/name
  final int? selectedId; // null = 전체
  final ValueChanged<int?> onSelected;
  final bool enabled; // 요청 중에는 false로 내려서 장르 변경을 막음

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('전체'),
            selected: selectedId == null,
            showCheckmark: false,
            onSelected: enabled ? (_) => onSelected(null) : null,
          ),
          const SizedBox(width: 8),
          for (final genre in genres) ...[
            ChoiceChip(
              label: Text(genre.name),
              selected: genre.id == selectedId,
              showCheckmark: false,
              onSelected: enabled ? (_) => onSelected(genre.id) : null,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
