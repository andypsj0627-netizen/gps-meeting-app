import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_summary.dart';

/// 화면 개발용 Fake 대화 목록 데이터. 스침 탭 인물과 일관된 상대를 사용한다.
const List<ChatSummary> _fakeChats = [
  ChatSummary(
    id: 'user2',
    partnerName: '이서연',
    lastMessage: '저도 그 카페 자주 가요!',
    timeLabel: '오후 2:30',
    unreadCount: 2,
  ),
  ChatSummary(
    id: 'user5',
    partnerName: '정도윤',
    lastMessage: '내일 시간 어때요?',
    timeLabel: '어제',
    unreadCount: 0,
  ),
];

/// 대화 목록 화면에 표시할 채팅 요약 목록을 제공한다.
///
/// 현재는 Fake 데이터를 반환한다. 실제 채팅 백엔드 연결 시 이 provider를 교체한다.
final chatListProvider = Provider<List<ChatSummary>>((ref) => _fakeChats);
