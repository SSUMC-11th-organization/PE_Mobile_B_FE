import 'package:flutter/material.dart';

import '../widgets/movielog_button.dart';

// MovieLogButton의 width/비활성/로딩 상태를 한 화면에서 비교하는 개발용 데모 화면
class ButtonWidthDemoScreen extends StatelessWidget {
  const ButtonWidthDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MovieLogButton 데모')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _DemoLabel('width: null'),
          Row(
            children: [
              const Expanded(child: TextField()),
              const SizedBox(width: 8),
              MovieLogButton(label: '중복 확인', onPressed: () {}),
            ],
          ),
          const _DemoLabel('width: double.infinity'),
          MovieLogButton(
            label: '가입하기',
            width: double.infinity,
            onPressed: () {},
          ),
          const _DemoLabel('width: 96'),
          Align(
            alignment: Alignment.centerLeft,
            child: MovieLogButton(label: 'OK', width: 96, onPressed: () {}),
          ),
          const _DemoLabel('비활성(onPressed: null)'),
          const Align(
            alignment: Alignment.centerLeft,
            child: MovieLogButton(label: '비활성', onPressed: null),
          ),
          const _DemoLabel('통신 중(isLoading)'),
          Align(
            alignment: Alignment.centerLeft,
            child: MovieLogButton(
              label: '통신 중',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoLabel extends StatelessWidget {
  const _DemoLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text),
    );
  }
}
