import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../view_models/auth_view_model.dart';

/// 8주차: 내 정보를 한 번 불러오려고 StatelessWidget → StatefulWidget으로 변경.
/// 탭을 바꿔도 이 위젯은 유지되고 child만 바뀌므로 initState는 로그인당 한 번만 실행
class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  final int currentIndex;
  final Widget child;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    // loadMember()는 첫 줄에서 notifyListeners()를 부르므로 build 도중이 아닌 첫 프레임 뒤에 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 어느 탭으로 진입하든 내 정보를 한 번 불러와 AuthViewModel.member에 보관
      if (mounted) context.read<AuthViewModel>().loadMember();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/movies');
            case 2:
              context.go('/my');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.movie_outlined),
            selectedIcon: Icon(Icons.movie),
            label: '영화',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '마이',
          ),
        ],
      ),
    );
  }
}
