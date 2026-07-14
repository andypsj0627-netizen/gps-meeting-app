import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_summary.dart';
import '../providers/chat_list_provider.dart';

/// 상호 호감이 성립한 상대와의 대화 목록 화면.
///
/// 현재는 Fake 데이터를 보여주며, 실제 채팅방 진입은 아직 준비중이다.
class ChatListScreen extends ConsumerWidget {
  /// 기본 생성자.
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('대화')),
      body: chats.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) => _ChatTile(chat: chats[index]),
            ),
    );
  }
}

/// 대화가 하나도 없을 때 보여줄 빈 상태 UI.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: color),
          const SizedBox(height: 16),
          Text('아직 대화가 없어요', style: TextStyle(color: color)),
          const SizedBox(height: 4),
          Text(
            '서로 호감을 표시하면 대화가 열려요',
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}

/// 대화 목록의 한 항목 타일.
class _ChatTile extends StatelessWidget {
  /// 표시할 대화 요약.
  final ChatSummary chat;

  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          // 실데이터 전환 시 이름 없는 문서가 올 수 있다 — 빈 문자열 가드.
          chat.partnerName.isEmpty ? '?' : chat.partnerName.characters.first,
        ),
      ),
      title: Text(chat.partnerName),
      subtitle: Text(
        chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            chat.timeLabel,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (chat.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${chat.unreadCount}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('대화방은 준비중이에요')),
        );
      },
    );
  }
}
