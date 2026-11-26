import 'package:flutter/material.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import 'movie_card.dart';

class MovieGrid extends StatelessWidget {
  const MovieGrid({
    super.key,
    required this.movies,
    required this.genres,
    this.footer,
  });

  final List<TmdbMovieDto> movies;
  // 카드에 장르 이름을 표시하기 위한 Genre API 결과
  final List<TmdbGenreDto> genres;
  // 9주차: 카드 목록 아래에 붙이는 위젯 (더 보기·재시도·끝 상태)
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final item = movies[index];
              final genreName = genres
                  .where((genre) => item.genreIds.contains(genre.id))
                  .map((genre) => genre.name)
                  .firstOrNull;
              return MovieCard(movie: item, genreName: genreName);
            },
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: 0.55,
            ),
          ),
        ),
        if (footer != null) SliverToBoxAdapter(child: footer),
      ],
    );
  }
}
