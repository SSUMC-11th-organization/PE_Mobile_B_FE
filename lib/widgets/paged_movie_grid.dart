import 'package:flutter/material.dart';

import '../view_models/paged_movies_view_model.dart';
import 'movie_card.dart';
import 'movie_page_footer.dart';

const movieGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 12,
  mainAxisSpacing: 16,
  childAspectRatio: 0.65,
);

/// 영화 카드 격자 + 더 보기 footer. 목록 화면과 검색 화면이 함께 씁니다.
class PagedMovieGrid extends StatelessWidget {
  const PagedMovieGrid({super.key, required this.viewModel});

  final PagedMoviesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverGrid.builder(
            gridDelegate: movieGridDelegate,
            itemCount: viewModel.movies.length,
            itemBuilder: (context, index) =>
                MovieCard(movie: viewModel.movies[index]),
          ),
        ),
        SliverToBoxAdapter(child: MoviePageFooter(viewModel: viewModel)),
      ],
    );
  }
}
