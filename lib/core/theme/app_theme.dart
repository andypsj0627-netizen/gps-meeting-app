import 'package:flutter/material.dart';

/// 앱의 Material 3 라이트/다크 테마 정의.
class AppTheme {
  const AppTheme._();

  /// 테마의 시드 색상.
  static const Color _seedColor = Colors.indigo;

  /// 라이트 테마.
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      );

  /// 다크 테마.
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
      );
}
