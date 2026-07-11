import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  // Firebase 초기화는 첫 프레임을 지연시키지 않도록 firebaseInitProvider에서
  // lazy하게 수행한다(프로필은 fallback이 있는 부가 기능).
  // Riverpod provider 트리를 앱 전체에 제공한다.
  runApp(const ProviderScope(child: MyApp()));
}

/// 앱 루트 위젯.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
