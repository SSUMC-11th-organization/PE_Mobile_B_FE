import 'package:flutter/material.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../theme/app_colors.dart';

class GenreChips extends StatelessWidget {
  const GenreChips({
    super.key,
    required this.genres,
    required this.selectedId,
    required this.onSelected,
  });

  final List<TmdbGenreDto> genres;
  // null이면 "전체"
  final int? selectedId;
  // null이면 모든 칩이 비활성화된다 (요청 중 장르 변경 방지)
  final ValueChanged<int?>? onSelected;

  @override
  Widget build(BuildContext context) {
    final onSelected = this.onSelected;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // 맨 앞에 "전체" 칩을 하나 더 둔다
        itemCount: genres.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final id = index == 0 ? null : genres[index - 1].id;
          final label = index == 0 ? '전체' : genres[index - 1].name;
          final isSelected = id == selectedId;
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            showCheckmark: false,
            onSelected: onSelected == null ? null : (_) => onSelected(id),
            selectedColor: AppColors.violet,
            backgroundColor: AppColors.violetLight,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            labelStyle: TextStyle(
              color: isSelected ? AppColors.white : AppColors.black,
              fontWeight: FontWeight.w700,
            ),
          );
        },
      ),
    );
  }
}
