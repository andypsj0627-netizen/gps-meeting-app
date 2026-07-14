import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/chat/models/chat_summary.dart';
import 'package:gps_meeting_app/features/chat/providers/chat_list_provider.dart';
import 'package:gps_meeting_app/features/chat/screens/chat_list_screen.dart';

void main() {
  testWidgets('기본 데이터로 대화 목록이 렌더된다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ChatListScreen()),
      ),
    );

    expect(find.text('이서연'), findsOneWidget);
    expect(find.text('정도윤'), findsOneWidget);
    expect(find.text('저도 그 카페 자주 가요!'), findsOneWidget);
  });

  testWidgets('안읽음 뱃지가 표시된다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ChatListScreen()),
      ),
    );

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('타일을 탭하면 준비중 스낵바가 뜬다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ChatListScreen()),
      ),
    );

    await tester.tap(find.text('이서연'));
    await tester.pump();

    expect(find.text('대화방은 준비중이에요'), findsOneWidget);
  });

  testWidgets('빈 목록이면 빈 상태 UI가 뜬다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatListProvider.overrideWithValue(const <ChatSummary>[]),
        ],
        child: const MaterialApp(home: ChatListScreen()),
      ),
    );

    expect(find.text('아직 대화가 없어요'), findsOneWidget);
  });
}
