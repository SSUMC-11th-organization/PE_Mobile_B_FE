import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../view_models/favorite_detail_view_model.dart';
import '../../view_models/movie_detail_view_model.dart';
import '../../view_models/submit_status.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/tmdb_poster_image.dart';
import 'widgets/rating_dialog.dart';

/// 영화 정보는 MovieDetailLoader가 만든 MovieDetailViewModel에서 읽음. (8주차: memberId 대신 토큰으로 등록)
/// 이 화면은 평점 "등록"만 하고, 조회·수정·삭제는 마이페이지의 내가 등록한 평점 화면에서 진행.
/// 9주차: 3주차의 mock 즐겨찾기 상태·버튼을 제거하고, 서버 상태를 따르는 FavoriteButton을 제목 옆에 배치
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  @override
  void initState() {
    super.initState();
    // 화면이 처음 만들어질 때 서버의 즐겨찾기 여부를 한 번만 조회 (build()에서는 조회하지 않음)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoriteDetailViewModel>().load();
    });
  }

  Future<void> _openRatingDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막음
      builder: (_) => RatingDialog(
        onSubmit: (score, comment) async {
          // movieId는 ViewModel이 이미 갖고 있으므로 따로 넘기지 않음
          final viewModel = context.read<MovieDetailViewModel>();
          await viewModel.createRating(score: score, comment: comment);
          if (viewModel.submitStatus != SubmitStatus.success) {
            // 실패는 Dialog가 받아 서버 message(400/409 등)를 보여주고 입력을 유지.
            // 401(세션 만료)이면 ViewModel이 세션을 정리해 Router가 로그인 화면으로 보냄
            throw StateError(viewModel.submitMessage ?? '저장에 실패했습니다.');
          }
        },
      ),
    );

    // 저장 요청과 Snackbar 표시는 서로 다른 비동기 경계라 mounted를 다시 확인
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MovieDetailViewModel>();
    final movie = viewModel.movie;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          'Cinema Archive',
          style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.share))],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AspectRatio(
            aspectRatio: 0.66,
            child: TmdbPosterImage(
              posterPath: movie.posterPath,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목·정보 텍스트는 그대로 두고, 오른쪽에 북마크 버튼을 배치
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movie.title,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${movie.releaseDate ?? '개봉일 미정'} · ★ ${movie.voteAverage.toStringAsFixed(1)}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const FavoriteButton(),
                  ],
                ),
                const SizedBox(height: 24),
                if (movie.overview.isEmpty)
                  const Center(child: Text('줄거리 정보가 없어요.'))
                else
                  Text(movie.overview, style: textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 왼쪽에 있던 즐겨찾기 버튼이 제목 옆으로 옮겨져서 평점 버튼이 전체 너비를 사용
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  // 이 화면은 로그인 상태에서만 열림 (로그아웃 상태면 Router가 /login으로 보냄)
                  onPressed: _openRatingDialog,
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('평점 남기기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
