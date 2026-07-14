import 'package:flutter/material.dart';

import '../../../shared/widgets/coming_soon_screen.dart';

/// 겹침 피드 예정 — docs/encounter-tiers.md 참조.
class EncountersScreen extends StatelessWidget {
  const EncountersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: '스침',
      icon: Icons.auto_awesome,
      message: '곧 겹침 피드가 열려요',
    );
  }
}
