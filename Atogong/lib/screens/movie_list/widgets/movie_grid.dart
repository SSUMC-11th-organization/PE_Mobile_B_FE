import 'package:flutter/material.dart';

import '../../../data/models/tmdb_movie_dto.dart';
import '../../../widgets/movie_card.dart';

class MovieGrid extends StatefulWidget {
  const MovieGrid({super.key, required this.movies, this.footer});

  final List<TmdbMovieDto> movies;
  // 9주차: 카드 목록 아래에 붙는 더 보기 영역. Grid와 함께 스크롤되도록 같은 ScrollView에 넣음
  final Widget? footer;

  @override
  State<MovieGrid> createState() => _MovieGridState();
}

class _MovieGridState extends State<MovieGrid> {
  // 스크롤 위치를 기억하지 않게 함. 기억해 두면 아래까지 내린 상태에서 장르를 바꿨을 때
  // 새 목록이 맨 위가 아니라 이전 위치에서 시작함
  final _controller = ScrollController(keepScrollOffset: false);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _controller,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 24,
              childAspectRatio: 0.55,
            ),
            itemCount: widget.movies.length,
            itemBuilder: (context, index) =>
                MovieCard(movie: widget.movies[index]),
          ),
        ),
        if (widget.footer != null) SliverToBoxAdapter(child: widget.footer),
      ],
    );
  }
}
