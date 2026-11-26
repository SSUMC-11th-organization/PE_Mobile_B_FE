import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_list_states.dart';
import '../widgets/paged_movie_grid.dart';

class MovieSearchScreen extends StatefulWidget {
  const MovieSearchScreen({super.key});

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  final _text = TextEditingController();
  String? _inputError;

  /// 제출할 때만 요청하며, 빈 검색어는 서버에 보내지 않습니다.
  void _submit(String value) {
    final query = value.trim();
    setState(() => _inputError = query.isEmpty ? '검색어를 입력해 주세요.' : null);
    if (query.isEmpty) return;
    context.read<PagedMoviesViewModel>().loadInitial(query: query);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PagedMoviesViewModel>();
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화 검색',
        centerTitle: true,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _text,
                textInputAction: TextInputAction.search,
                onSubmitted: _submit,
                decoration: InputDecoration(
                  labelText: '검색어',
                  errorText: _inputError,
                  suffixIcon: IconButton(
                    tooltip: '검색',
                    icon: const Icon(Icons.search),
                    onPressed: () => _submit(_text.text),
                  ),
                ),
              ),
            ),
            Expanded(
              child: switch (vm.phase) {
                LoadPhase.idle => const Center(child: Text('영화 제목을 검색해 보세요.')),
                LoadPhase.loading => const MovieListLoading(),
                LoadPhase.error => MovieListError(
                    message: vm.errorMessage ?? '조회 오류입니다.',
                    onRetry: vm.retry,
                  ),
                LoadPhase.empty => const MovieListEmpty(message: '검색 결과가 없습니다.'),
                LoadPhase.ready => PagedMovieGrid(viewModel: vm),
              },
            ),
          ],
        ),
      ),
    );
  }
}
