import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/models/auth_user.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/encounters/screens/encounters_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/map/screens/map_screen.dart';
import '../../features/profile/screens/my_page_screen.dart';
import '../../features/shell/screens/main_shell.dart';
import '../constants/app_constants.dart';
import '../firebase/firebase_providers.dart';

/// 로그인 요구 여부 provider.
///
/// [AppConstants.requireLogin]을 감싸 라우터가 이 값을 watch하게 한다. 테스트에서
/// 이 provider를 override해 우회 모드/인증 모드를 각각 검증하는 진입점이다.
final requireLoginProvider = Provider<bool>((ref) => AppConstants.requireLogin);

/// 지도 셸 라우트를 매 호출마다 새로 만든다.
///
/// 우회/인증 두 라우터가 GoRoute 인스턴스를 공유하면 dispose가 꼬이므로,
/// 각 브랜치에서 이 함수를 호출해 서로 독립된 라우트 트리를 갖게 한다.
/// indexedStack이라 탭 전환 시 지도 브랜치의 State가 보존된다(지도 미dispose — 의도).
StatefulShellRoute _buildMapShellRoute() {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) =>
        MainShell(navigationShell: navigationShell),
    branches: [
      StatefulShellBranch(routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      ]),
      StatefulShellBranch(routes: [
        GoRoute(path: '/', builder: (context, state) => const MapScreen()),
      ]),
      StatefulShellBranch(routes: [
        GoRoute(
          path: '/encounters',
          builder: (context, state) => const EncountersScreen(),
        ),
      ]),
      StatefulShellBranch(routes: [
        GoRoute(
          path: '/chats',
          builder: (context, state) => const ChatListScreen(),
        ),
      ]),
      StatefulShellBranch(routes: [
        GoRoute(path: '/my', builder: (context, state) => const MyPageScreen()),
      ]),
    ],
  );
}

/// 앱 라우터 provider.
///
/// GoRouter는 provider가 살아 있는 동안 **한 번만** 생성한다. authState를
/// watch해서 라우터를 다시 만들면 매 인증 변화마다 라우터가 재생성되어
/// 네비게이션 스택이 초기화된다. 대신 인증 상태를 [ValueNotifier]에 담아
/// refreshListenable로 넘겨, 라우터 인스턴스는 유지한 채 redirect만 다시
/// 평가되게 한다.
final routerProvider = Provider<GoRouter>((ref) {
  // 우회 모드: 로그인 화면·인증 배선(ValueNotifier/ref.listen/refreshListenable/
  // redirect) 전부 생략하고 바로 지도('/')로 진입한다. authStateChangesProvider가
  // 라우터 경유로 활성화되지 않으므로 Firebase init도 라우터가 켜지 않는다.
  // Firebase init은 기존처럼 userProfilesProvider가 필요할 때 lazy 실행되고,
  // 인증 없는 Firestore 접근은 permission-denied → 기본 5인 fallback으로 동작한다.
  // 로그인 화면 코드 보존을 위해 라우트 3개는 인증 모드와 동일하게 등록한다.
  if (!ref.watch(requireLoginProvider)) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/splash',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: _SplashScreen()),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        _buildMapShellRoute(),
      ],
    );
    ref.onDispose(router.dispose);
    return router;
  }

  // 인증 상태를 refreshListenable이 감지할 수 있는 ValueNotifier로 옮긴다.
  final notifier = ValueNotifier<AsyncValue<AuthUser?>>(const AsyncLoading());
  ref.listen(
    authStateChangesProvider,
    (prev, next) => notifier.value = next,
    fireImmediately: true,
  );
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    // 인증 상태에 따라 접근 경로를 통제한다.
    // - 에러(초기화/인증 스트림 실패): 스플래시에 머물러 복구 UI를 보여준다.
    // - 로딩 중(아직 첫 값 없음): 스플래시에 머문다.
    // - 미로그인: 로그인 화면으로 보낸다.
    // - 로그인됨: 스플래시/로그인에 있으면 지도로 보낸다.
    redirect: (context, state) {
      final auth = notifier.value;
      final loc = state.matchedLocation;
      // Firebase 초기화/인증 스트림 에러: 스플래시에 머물러 복구 UI를 보여준다.
      // (fresh AsyncError는 isLoading==false라, 이 분기가 없으면 아래에서 user==null로
      //  흘러 로그인 화면으로 잘못 새어나간다.)
      if (auth.hasError) {
        return loc == '/splash' ? null : '/splash';
      }
      if (auth.isLoading && !auth.hasValue) {
        return loc == '/splash' ? null : '/splash';
      }
      final user = auth.value;
      if (user == null) {
        return loc == '/login' ? null : '/login';
      }
      if (loc == '/splash' || loc == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        // 스피너→스피너 전환 애니메이션을 없앤다.
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: _SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      _buildMapShellRoute(),
    ],
  );

  // Riverpod onDispose는 FIFO(등록 순=실행 순)이므로, refreshListenable(notifier)에
  // 의존하는 router를 먼저 등록해 먼저 정리한다.
  ref.onDispose(router.dispose);
  ref.onDispose(notifier.dispose);

  return router;
});

/// 인증 상태 확인 중 잠깐 표시하는 스플래시 화면.
///
/// 초기화/인증 스트림 에러 시에는 복구 UI(에러 안내 + 다시 시도)를 보여준다.
class _SplashScreen extends ConsumerWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateChangesProvider);
    if (auth.hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                '앱을 시작하지 못했어요. 잠시 후 다시 시도해주세요.',
                key: ValueKey('splash_error_text'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const ValueKey('splash_retry_button'),
                // firebaseInitProvider를 invalidate하면 이를 watch하는
                // authStateChangesProvider가 연쇄로 다시 실행되어 재시도된다.
                onPressed: () => ref.invalidate(firebaseInitProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
