import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/encounters/models/encounter_card.dart';
import 'package:gps_meeting_app/features/encounters/models/encounter_tier.dart';
import 'package:gps_meeting_app/features/encounters/providers/encounter_feed_provider.dart';
import 'package:gps_meeting_app/features/encounters/screens/encounters_screen.dart';

/// 지정한 리스트를 그대로 반환하는 테스트용 피드 Notifier.
class _TestFeedNotifier extends EncounterFeedNotifier {
  _TestFeedNotifier(this.cards);

  final List<EncounterCard> cards;

  @override
  List<EncounterCard> build() => cards;
}

Widget _wrap(List<EncounterCard> cards) {
  return ProviderScope(
    overrides: [
      encounterFeedProvider.overrideWith(() => _TestFeedNotifier(cards)),
    ],
    child: const MaterialApp(home: EncountersScreen()),
  );
}

const _brushCard = EncounterCard(
  id: 'b1',
  tier: EncounterTier.brush,
  displayName: 'ㅎ',
  ageLabel: '20대',
  contextLine: '이번 주 3번째 스침',
  placeLabel: '망원동 부근',
  timeLabel: '어제 저녁',
);

const _fateCard = EncounterCard(
  id: 'f1',
  tier: EncounterTier.fate,
  displayName: '박지훈',
  ageLabel: '29',
  bio: '러닝 크루',
  contextLine: '한 달째 같은 코스',
  placeLabel: '반포 부근',
  timeLabel: '방금 전',
  isNearbyNow: true,
);

void main() {
  testWidgets('스침 카드는 이니셜만 보이고 실명은 안 보인다', (tester) async {
    await tester.pumpWidget(_wrap(const [_brushCard]));
    await tester.pump();

    expect(find.text('ㅎ · 20대'), findsOneWidget);
    expect(find.text('한예린'), findsNothing);
  });

  testWidgets('운명 카드는 지금 근처 뱃지를 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(const [_fateCard]));
    await tester.pump();

    expect(find.text('지금 근처'), findsOneWidget);
  });

  testWidgets('호감 버튼을 탭하면 채워진 하트로 바뀐다', (tester) async {
    await tester.pumpWidget(_wrap(const [_brushCard]));
    await tester.pump();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('피드가 비면 빈 상태 문구가 보인다', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pump();

    expect(find.text('아직 스친 인연이 없어요'), findsOneWidget);
  });
}
