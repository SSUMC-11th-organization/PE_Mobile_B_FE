import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../view_models/movie_detail_view_model.dart';
import '../../view_models/submit_status.dart';
import '../../widgets/tmdb_poster_image.dart';
import 'widgets/rating_dialog.dart';

/// 영화 정보와 memberId는 MovieDetailLoader가 만든 MovieDetailViewModel에서 읽음.
/// 이 화면은 평점 "등록"만 하고, 조회·수정·삭제는 마이페이지의 내가 등록한 평점 화면에서 진행
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
            // 실패는 Dialog가 받아 서버 message(400/404/409)를 보여주고 입력을 유지
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
    final canRate =
        viewModel.memberId != null; // 회원가입 전에는 평점 path에 쓸 memberId가 없음
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
              if (!canRate)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '평점을 남기려면 먼저 회원가입을 완료해 주세요.',
                    style: textTheme.bodySmall,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _toggleFavorite,
                      icon: Icon(
                        _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      label: const Text('즐겨찾기'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canRate ? _openRatingDialog : null,
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('평점 남기기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
