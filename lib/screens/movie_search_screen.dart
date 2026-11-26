import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_page_footer.dart';
import '../widgets/movielog_button.dart';

// 영화 검색 — 영화 목록과 별도의 PagedMoviesViewModel 인스턴스 (Route에서 생성)
// 검색어를 제출할 때만 요청 (입력할 때마다 요청하지 않음, 디바운스 없음)
// 새 검색은 loadInitial로 이전 결과·page·오류를 모두 비우고 첫 page부터
class MovieSearchScreen extends StatefulWidget {
  const MovieSearchScreen({super.key});

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  static const _emptyQueryMessage = '검색어를 입력하세요';

  final _controller = TextEditingController();
  String? _inputError;

  void _submit(String value) {
    final query = value.trim();
    // 빈 검색어·공백만 있는 검색어는 서버에 보내지 않음
    if (query.isEmpty) {
      setState(() => _inputError = _emptyQueryMessage);
      return;
    }
    setState(() => _inputError = null);
    context.read<PagedMoviesViewModel>().loadInitial(query: query);
  }

  void _clear() {
    _controller.clear();
    setState(() => _inputError = null);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화 검색',
        centerTitle: true,
        onBack: () => context.canPop() ? context.pop() : context.go('/movies'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search, // 키보드 검색 버튼
                onSubmitted: _submit,
                decoration: InputDecoration(
                  hintText: '영화 제목을 입력하세요',
                  errorText: _inputError,
                  prefixIcon: const Icon(Icons.search),
                  // 입력이 있을 때만 지우기 버튼
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            tooltip: '지우기',
                            icon: const Icon(Icons.clear),
                            onPressed: _clear,
                          ),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: Consumer<PagedMoviesViewModel>(
                builder: (context, vm, _) => _buildBody(vm),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(PagedMoviesViewModel vm) {
    switch (vm.phase) {
      // 아직 검색하지 않음 — 입력 안내
      case LoadPhase.idle:
        return const _SearchMessage(
          icon: Icons.manage_search,
          iconColor: AppColors.gray,
          message: _emptyQueryMessage,
        );
      // 첫 page 로딩
      case LoadPhase.loading:
        return const Center(child: CircularProgressIndicator());
      // 조회 오류 — 메시지 + 다시 시도 (결과 없음과 다른 화면)
      case LoadPhase.error:
        return _SearchMessage(
          icon: Icons.error_outline,
          iconColor: AppColors.error,
          message: vm.errorMessage ?? '검색 결과를 불러오지 못했습니다.',
          action: MovieLogButton(label: '다시 시도', onPressed: vm.retry),
        );
      // 요청은 성공했지만 결과 없음
      case LoadPhase.empty:
        return _SearchMessage(
          icon: Icons.search_off,
          iconColor: AppColors.gray,
          message: '검색 결과가 없습니다\n"${vm.condition.query}"',
        );
      // 검색 결과 — 2열 그리드 + 더 보기/재시도 footer (카드를 누르면 기존 상세로 이동)
      case LoadPhase.ready:
        return CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.65,
                ),
                itemCount: vm.movies.length,
                itemBuilder: (context, index) =>
                    MovieCard(movie: vm.movies[index]),
              ),
            ),
            SliverToBoxAdapter(child: MoviePageFooter(vm: vm)),
          ],
        );
    }
  }
}

// 가운데 아이콘 + 문구 (+ 버튼) — 입력 안내·결과 없음·오류 (아이콘·색·버튼으로 구분)
class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
