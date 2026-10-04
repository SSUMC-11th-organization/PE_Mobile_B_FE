import 'package:flutter/material.dart';

import '../../../data/mock_movies.dart';

class GenreFilterSheet extends StatefulWidget {
  const GenreFilterSheet({super.key, required this.initialSelected});

  final Set<String> initialSelected;

  @override
  State<GenreFilterSheet> createState() => _GenreFilterSheetState();
}

class _GenreFilterSheetState extends State<GenreFilterSheet> {
  late final Set<String> _selected = {...widget.initialSelected};

  // '전체'는 제외
  List<String> get _options => genres.where((g) => g != '전체').toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                '장르 선택',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  final genre = _options[index];
                  return CheckboxListTile(
                    title: Text(genre),
                    value: _selected.contains(genre),
                    onChanged: (checked) => setState(() {
                      checked == true
                          ? _selected.add(genre)
                          : _selected.remove(genre);
                    }),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text('확인'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
