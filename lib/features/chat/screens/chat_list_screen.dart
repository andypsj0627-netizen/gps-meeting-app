import 'package:flutter/material.dart';

import '../../../shared/widgets/coming_soon_screen.dart';

/// 상호 호감 채팅 목록 예정.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: '대화',
      icon: Icons.chat_bubble_outline,
      message: '상호 호감이 생기면 대화가 시작돼요',
    );
  }
}
