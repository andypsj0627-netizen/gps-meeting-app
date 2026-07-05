import 'package:go_router/go_router.dart';

import '../../features/map/screens/map_screen.dart';

/// 앱 라우터 설정.
///
/// 현재는 루트 경로('/')를 지도 화면에 연결한다. 이후 Phase에서 라우트를 추가한다.
final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MapScreen(),
    ),
  ],
);
