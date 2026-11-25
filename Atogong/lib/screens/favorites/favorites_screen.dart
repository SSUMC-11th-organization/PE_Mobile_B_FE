import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/tmdb_movie_dto.dart';
import '../../view_models/favorites_view_model.dart';
import '../../view_models/load_phase.dart';
import '../../widgets/movielog_button.dart';

/// 마이페이지의 자식 화면. root Navigator 위에 떠서 하단 NavigationBar가 없고, AppBar 뒤로가기로 복귀.
/// 목록 / 빈 목록 / 조회 오류 / 영화 정보 한 건 실패를 서로 다른 화면으로 구분
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.onOpenMovie});

  // 상세로 이동했다가 돌아올 때까지 기다릴 수 있도록 Future를 반환
  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FavoritesViewModel>().refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('내 즐겨찾기'), centerTitle: true),
    body: Consumer<FavoritesViewModel>(
      builder: (context, vm, _) {
        if (vm.phase == LoadPhase.idle || vm.phase == LoadPhase.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (vm.phase == LoadPhase.empty) {
          return const Center(child: Text('아직 즐겨찾기한 영화가 없습니다.'));
        }

        if (vm.phase == LoadPhase.error) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(vm.errorMessage ?? '조회 오류입니다.'),
                const SizedBox(height: 12),
                MovieLogButton(label: '다시 시도', onPressed: vm.refresh),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: vm.refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: vm.items.length,
            itemBuilder: (context, index) {
              final item = vm.items[index], movie = item.movie;

              // 영화 정보를 못 가져온 카드만 placeholder + 재조회. 다른 카드는 그대로 둠
              if (movie == null) {
                return ListTile(
                  leading: const Icon(Icons.broken_image_outlined),
                  title: Text('TMDB #${item.favorite.movieId}'),
                  subtitle: Text(item.errorMessage ?? '정보가 없습니다.'),
                  trailing: MovieLogButton(
                    width: 110,
                    label: '정보 재조회',
                    onPressed: vm.refresh,
                  ),
                );
              }

              final path = movie.posterPath;

              return ListTile(
                leading: path == null
                    ? const Icon(Icons.movie_outlined)
                    : Image.network(
                        'https://image.tmdb.org/t/p/w185$path',
                        width: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                title: Text(movie.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await widget.onOpenMovie(movie);

                  if (!mounted) return;

                  // 상세에서 해제하고 돌아왔을 수 있으므로 목록을 다시 조회
                  await vm.refresh();
                },
              );
            },
          ),
        );
      },
    ),
  );
}
