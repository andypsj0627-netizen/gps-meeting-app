/// 대화 목록 화면의 한 항목을 나타내는 뷰모델.
///
/// 상호 호감이 성립한 상대와의 채팅방을 요약해 보여주기 위한 순수 데이터 클래스다.
class ChatSummary {
  /// 대화 상대의 고유 식별자.
  final String id;

  /// 대화 상대의 표시 이름.
  final String partnerName;

  /// 마지막으로 주고받은 메시지 내용.
  final String lastMessage;

  /// 목록에 표시할 시각 라벨. 예: '오후 2:30', '어제'.
  final String timeLabel;

  /// 읽지 않은 메시지 개수. 0이면 뱃지를 표시하지 않는다.
  final int unreadCount;

  /// 모든 필드를 받는 const 생성자.
  const ChatSummary({
    required this.id,
    required this.partnerName,
    required this.lastMessage,
    required this.timeLabel,
    required this.unreadCount,
  });
}
