import 'package:flutter/material.dart';

class GenreChips extends StatelessWidget {
  const GenreChips({
    super.key,
    required this.genres,
    required this.selected,
    required this.onSelected,
  });

  final List<String> genres;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final genre in genres) ...[
            ChoiceChip(
              label: Text(genre),
              selected: genre == selected,
              showCheckmark: false,
              onSelected: (_) => onSelected(genre),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
