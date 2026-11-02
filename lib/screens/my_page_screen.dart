import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// 마이페이지 탭 — 지금은 자리만 잡아둠
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('마이페이지'),
            ),
            // push = 탭 위에 평점 화면을 쌓음 → 뒤로가기로 마이 탭에 돌아옴
            ListTile(
              title: const Text('내가 등록한 평점'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/my/ratings'),
            ),
          ],
        ),
      ),
    );
  }
}
