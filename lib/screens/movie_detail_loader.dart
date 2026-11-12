import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../theme/app_text_styles.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/movie_detail_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';
import 'movie_detail_screen.dart';

// 영화 상세 진입점 — 카드에서 받은 영화가 있으면 그대로 쓰고,
// 없으면(URL 직접 진입 등) TMDB 상세를 한 번 불러온 뒤 MovieDetailScreen을 띄움
class MovieDetailLoader extends StatefulWidget {
  const MovieDetailLoader({super.key, required this.movieId, this.initialMovie});

  final int? movieId; // 경로의 :movieId. 숫자가 아니면 null
  final TmdbMovieDto? initialMovie; // id가 movieId와 같을 때만 전달됨

  @override
  State<MovieDetailLoader> createState() => _MovieDetailLoaderState();
}

class _MovieDetailLoaderState extends State<MovieDetailLoader> {
  Future<TmdbMovieDto>? _future;

  @override
  void initState() {
    super.initState();
    // build가 아니라 initState에서 한 번만 요청
    if (widget.initialMovie == null && widget.movieId != null) {
      _future = _fetch(widget.movieId!);
    }
  }

  Future<TmdbMovieDto> _fetch(int movieId) =>
      context.read<TmdbMovieService>().fetchMovieDetail(movieId);

  void _retry() {
    final movieId = widget.movieId;
    if (movieId == null) return;
    setState(() {
      _future = _fetch(movieId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialMovie;
    if (initial != null) return _buildDetail(initial);
    final future = _future;
    if (future == null) {
      return const _MessageScaffold(message: '영화를 찾을 수 없습니다');
    }
    return FutureBuilder<TmdbMovieDto>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _MessageScaffold(
            child: CircularProgressIndicator(),
          );
        }
        final movie = snapshot.data;
        if (snapshot.hasError || movie == null) {
          final error = snapshot.error;
          final notFound =
              error is DioException && error.response?.statusCode == 404;
          return _MessageScaffold(
            message: notFound
                ? '영화를 찾을 수 없습니다'
                : '영화 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
            onRetry: notFound ? null : _retry,
          );
        }
        return _buildDetail(movie);
      },
    );
  }

  Widget _buildDetail(TmdbMovieDto movie) {
    return ChangeNotifierProvider<MovieDetailViewModel>(
      create: (context) => MovieDetailViewModel(
        context.read<RatingApiService>(),
        context.read<LearningMemberSession>().memberId,
        movie,
      ),
      child: const MovieDetailScreen(),
    );
  }
}

// 로딩/실패 공통 화면 — 상세 화면과 같은 AppBar(뒤로가기 포함)
class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({this.message, this.child, this.onRetry});

  final String? message;
  final Widget? child;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화 상세',
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?child,
                if (message != null)
                  Text(
                    message!,
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  MovieLogButton(label: '다시 시도', onPressed: onRetry),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
