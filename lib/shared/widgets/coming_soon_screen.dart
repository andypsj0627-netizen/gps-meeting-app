import 'package:flutter/material.dart';

/// 스침/대화 탭이 재사용하는 준비중 공용 화면.
///
/// 각 탭이 자체 제목 바를 갖도록 [Scaffold] + [AppBar]를 포함한다.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}
