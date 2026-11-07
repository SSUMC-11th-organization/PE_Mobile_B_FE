import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../view_models/auth_view_model.dart';

// 하단 NavigationBar를 가진 탭 껍데기 화면. ShellRoute가 탭 화면을 child로 넣어줌
// 탭을 바꿔도 이 State는 유지됨 → 처음 열릴 때 한 번만 내 정보를 불러옴
class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.currentIndex, required this.child});

  final int currentIndex; // 현재 선택된 탭 (0: 홈, 1: 영화, 2: 마이)
  final Widget child; // 현재 경로에 해당하는 탭 화면

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    // 어느 탭으로 들어와도 마이페이지에 닉네임이 보이도록 여기서 조회
    // build 중 notifyListeners를 피하려고 첫 프레임 이후 호출
    // (이미 member가 있거나 signedIn이 아니면 loadMember가 아무것도 하지 않음)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthViewModel>().loadMember();
    });
  }

  @override
  Widget build(BuildContext context) {
    // canPop: false → 홈/영화/마이 어느 탭에서든 시스템 뒤로가기를 막음
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.currentIndex,
          // 탭 이동은 go → 탭끼리는 스택이 쌓이지 않음
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
      ),
    );
  }
}
