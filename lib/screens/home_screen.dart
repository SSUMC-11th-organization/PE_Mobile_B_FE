import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_text_styles.dart';
import '../view_models/movie_home_view_model.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_list_error.dart';

// 홈 화면 — TMDB 인기 영화 5편을 가로 스크롤 섹션으로 표시
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('오늘의 추천 영화', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              // 가로 ListView는 높이가 정해져 있어야 해서 SizedBox로 감쌈 — 상태가 바뀌어도 높이 유지
              SizedBox(
                height: 240,
                // 요청은 라우트에서 ViewModel 생성 시 한 번만 — 여기서는 상태만 보고 그림
                child: Consumer<MovieHomeViewModel>(
                  builder: (context, viewModel, _) {
                    switch (viewModel.status) {
                      case MovieHomeStatus.idle:
                      case MovieHomeStatus.loading:
                        return const Center(child: CircularProgressIndicator());
                      case MovieHomeStatus.error:
                        return MovieListError(
                          message: viewModel.errorMessage,
                          onRetry: viewModel.loadPopular,
                        );
                      case MovieHomeStatus.empty:
                        return const Center(child: Text('인기 영화가 없습니다.'));
                      case MovieHomeStatus.success:
                        final movies = viewModel.popularMovies;
                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: movies.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          // 가로 ListView 안에서는 폭이 무한대라 카드 폭을 지정
                          itemBuilder: (context, index) => SizedBox(
                            width: 140,
                            child: MovieCard(movie: movies[index]),
                          ),
                        );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
