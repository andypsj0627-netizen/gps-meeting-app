import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 5-탭 바텀 내비게이션의 셸.
///
/// go_router의 [StatefulNavigationShell]을 호스팅한다. indexedStack이므로 탭을
/// 전환해도 지도(및 GPS/시뮬레이션)의 State가 dispose되지 않고 유지된다 — 의도된 동작.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '홈'),
          NavigationDestination(icon: Icon(Icons.map), label: '지도'),
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: '스침'),
          NavigationDestination(icon: Icon(Icons.chat_bubble), label: '대화'),
          NavigationDestination(icon: Icon(Icons.person), label: '마이'),
        ],
      ),
    );
  }
}
