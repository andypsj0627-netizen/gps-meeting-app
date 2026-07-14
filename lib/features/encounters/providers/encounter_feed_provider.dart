import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/encounter_card.dart';
import '../models/encounter_tier.dart';

/// 스침 피드 상태를 들고 있는 Notifier.
///
/// 현재는 Fake 데이터만 반환한다 — 실제 겹침 원장/등급 엔진과의 결합은 별도 작업.
class EncounterFeedNotifier extends Notifier<List<EncounterCard>> {
  @override
  List<EncounterCard> build() {
    // 순수 동기 Fake 6건. Firebase/타이머/네트워크/DateTime.now() 금지.
    return const [
      EncounterCard(
        id: 'e1',
        tier: EncounterTier.brush,
        displayName: 'ㅎ',
        ageLabel: '20대',
        contextLine: '이번 주 3번째 스침 · 매번 화요일 저녁',
        placeLabel: '망원동 부근',
        timeLabel: '어제 저녁',
      ),
      EncounterCard(
        id: 'e2',
        tier: EncounterTier.brush,
        displayName: 'ㅇ',
        ageLabel: '20대',
        contextLine: '오늘 출근길에 두 번 겹침',
        placeLabel: '합정역 부근',
        timeLabel: '오늘 아침',
      ),
      EncounterCard(
        id: 'e3',
        tier: EncounterTier.bond,
        displayName: '김민준',
        ageLabel: '27',
        bio: '주말엔 자전거 타고 한강을 달려요.',
        contextLine: '5번 스치고 인연이 됐어요 · 주로 카페 골목',
        placeLabel: '연남동 부근',
        timeLabel: '이틀 전',
      ),
      EncounterCard(
        id: 'e4',
        tier: EncounterTier.bond,
        displayName: '최수아',
        ageLabel: '24',
        bio: '전시 보러 다니는 걸 좋아합니다.',
        contextLine: '같은 미술관에서 세 번 마주쳤어요',
        placeLabel: '삼청동 부근',
        timeLabel: '지난주',
      ),
      EncounterCard(
        id: 'e5',
        tier: EncounterTier.fate,
        displayName: '박지훈',
        ageLabel: '29',
        bio: '러닝 크루에서 활동 중이에요.',
        contextLine: '한 달째 같은 코스에서 겹치는 사람',
        placeLabel: '반포 한강공원 부근',
        timeLabel: '방금 전',
        isNearbyNow: true,
      ),
      EncounterCard(
        id: 'e6',
        tier: EncounterTier.connect,
        displayName: '이서연',
        ageLabel: '25',
        bio: '동네 책방 단골이에요.',
        contextLine: '서로 호감을 눌러 대화가 열렸어요',
        placeLabel: '서촌 부근',
        timeLabel: '어제',
        likedByMe: true,
      ),
    ];
  }

  /// 지정한 카드의 호감 상태를 반전한 새 리스트로 교체한다.
  void toggleLike(String id) {
    state = [
      for (final card in state)
        if (card.id == id)
          card.copyWith(likedByMe: !card.likedByMe)
        else
          card,
    ];
  }
}

/// 스침 피드 provider.
final encounterFeedProvider =
    NotifierProvider<EncounterFeedNotifier, List<EncounterCard>>(
  EncounterFeedNotifier.new,
);
