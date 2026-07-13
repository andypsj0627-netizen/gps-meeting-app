import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  // Firebase 초기화는 첫 프레임 이후 firebaseInitProvider에서 시작되며,
  // 스플래시가 그 시간을 가리고 auth가 라우팅 게이트로서 초기화 완료를 기다린다.
  // Riverpod provider 트리를 앱 전체에 제공한다.
  runApp(const ProviderScope(child: MyApp()));
}

/// 앱 루트 위젯.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
