import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/services/rating_api_service.dart' show RatingActionCancelled;
import '../theme/app_text_styles.dart';
import '../view_models/movie_detail_view_model.dart';
import '../view_models/sign_up_view_model.dart' show SubmitStatus;
import '../widgets/common_app_bar.dart';
import '../widgets/rating_dialog.dart';

// 영화 상세 화면 — 영화 정보와 평점 등록 상태는 MovieDetailLoader가 만든 MovieDetailViewModel에서 읽음
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  static const double _averageRating = 4.5; // 평균 평점 — API 연결 전 임시 값

  bool _isFavorite = false; // Mock 즐겨찾기 상태 — 화면을 나가면 초기화됨

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar() // 연속으로 눌러도 안내가 줄줄이 쌓이지 않게 이전 것을 닫음
      ..showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 제거했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _openRatingDialog(MovieDetailViewModel vm) async {
    // 저장 성공 시 다이얼로그가 true를 돌려줌. 제출 중에는 바깥 터치로 닫히지 않게 막음
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingDialog(
        onSubmit: (score, comment) async {
          await vm.createRating(score: score, comment: comment);
          // 세션 만료/세션 변경 → 문구 없이 진행 중 상태만 해제 (화면은 redirect로 사라짐)
          if (vm.submitStatus == SubmitStatus.idle) {
            throw const RatingActionCancelled();
          }
          if (vm.submitStatus != SubmitStatus.success) {
            throw StateError(
              vm.submitMessage ?? '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.',
            );
          }
        },
      ),
    );
    // State.context를 쓰므로 State의 mounted로 확인 (context.mounted와 같은 의미, lint 권장 형태)
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '평점을 등록했습니다. 마이페이지의 "평점 기록"에서 확인할 수 있습니다.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MovieDetailViewModel>();
    final movie = vm.movie;
    final year = movie.releaseYear;

    return Scaffold(
      // 상세 화면은 뒤로가기 허용 → 이전 화면이 있으면 pop,
      // 없으면(URL 직접 진입 등) 홈으로 이동
      appBar: CommonAppBar(
        title: movie.title,
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
            ),
            tooltip: _isFavorite ? '즐겨찾기 해제' : '즐겨찾기',
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(movie.title, style: AppTextStyles.titleLarge),
              if (year != null) ...[
                const SizedBox(height: 4),
                Text('$year', style: AppTextStyles.bodySmall),
              ],
              if (movie.overview.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(movie.overview, style: AppTextStyles.bodyMedium),
              ],
              const SizedBox(height: 24),
              // 평균 평점 — 읽기 전용 별 표시
              Row(
                children: [
                  RatingBarIndicator(
                    rating: _averageRating,
                    itemCount: 5,
                    itemSize: 20,
                    itemBuilder: (context, _) =>
                        const Icon(Icons.star, color: Colors.amber),
                  ),
                  const SizedBox(width: 8),
                  Text('평균 $_averageRating', style: AppTextStyles.bodySmall),
                ],
              ),
              const SizedBox(height: 16),
              // 로그인(signedIn) 상태에서만 이 화면에 올 수 있음 → 토큰으로 등록 (memberId 불필요)
              ElevatedButton(
                onPressed: () => _openRatingDialog(vm),
                child: const Text('평점 남기기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
