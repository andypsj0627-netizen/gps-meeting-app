import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:gps_meeting_app/features/map/providers/encounter_provider.dart';
import 'package:gps_meeting_app/features/map/services/encounter_detector.dart';

import 'helpers/location_test_helpers.dart';

void main() {
  /// dwell을 0으로 줄인 detector를 주입하는 override. 위젯 테스트는 tester.pump으로
  /// 짧은 시간만 전진시키므로 벽시계 10초를 채울 수 없다. dwell=0이면 진입한 그
  /// 방출은 pending 등록만 하고, 다음 방출에서 확정된다(2스텝).
  final zeroDwellDetector = [
    encounterDetectorProvider.overrideWith(
      (ref) => EncounterDetector(
        enterRadius: 60,
        exitRadius: 100,
        dwell: Duration.zero,
      ),
    ),
  ];

  testWidgets('근처 사용자가 진입 반경 이내로 들어오면 펄스 마커가 나타난다',
      (tester) async {
    final nearby = StreamController<List<NearbyUser>>();
    addTearDown(nearby.close);

    await pumpMapScreenWithService(
      tester,
      FakeLocationService(Stream.value(fakePosition(37.5665, 126.9780))),
      nearbyStream: nearby.stream,
      extraOverrides: zeroDwellDetector,
    );
    await tester.pump();
    await tester.pump();

    // 진입 반경 이내(10m)로 들어오면 pending에 등록된다(dwell=0에서도 확정은 다음
    // 방출에서).
    nearby.add([userAt('A', 10)]);
    await tester.pump();
    await tester.pump();

    // 같은 위치를 한 번 더 방출하면 pending이 dwell(0)을 충족해 나↔A 조우가
    // 확정된다.
    nearby.add([userAt('A', 10)]);
    await tester.pump();
    await tester.pump();

    // 첫 효과의 시퀀스는 0이다.
    expect(
      find.byKey(const ValueKey('encounter_pulse_0')),
      findsOneWidget,
    );

    // pending ticker로 실패하지 않도록 애니메이션을 소멸시킨다.
    await tester.pump(const Duration(milliseconds: 1600));
  });

  testWidgets('애니메이션 총 시간 경과 후 펄스 마커가 스스로 제거된다', (tester) async {
    final nearby = StreamController<List<NearbyUser>>();
    addTearDown(nearby.close);

    await pumpMapScreenWithService(
      tester,
      FakeLocationService(Stream.value(fakePosition(37.5665, 126.9780))),
      nearbyStream: nearby.stream,
      extraOverrides: zeroDwellDetector,
    );
    await tester.pump();
    await tester.pump();

    // 진입(pending) → 같은 위치 재방출(확정)의 2스텝으로 나↔A 조우를 확정시킨다.
    nearby.add([userAt('A', 10)]);
    await tester.pump();
    await tester.pump();

    nearby.add([userAt('A', 10)]);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('encounter_pulse_0')), findsOneWidget);

    // 총 재생 시간(1500ms) + 여유를 pump하면 완료 콜백이 목록에서 제거한다.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();

    expect(find.byKey(const ValueKey('encounter_pulse_0')), findsNothing);
  });

  testWidgets('동시 다건 조우면 펄스 마커가 여러 개 동시에 표시된다', (tester) async {
    final nearby = StreamController<List<NearbyUser>>();
    addTearDown(nearby.close);

    await pumpMapScreenWithService(
      tester,
      FakeLocationService(Stream.value(fakePosition(37.5665, 126.9780))),
      nearbyStream: nearby.stream,
      extraOverrides: zeroDwellDetector,
    );
    await tester.pump();
    await tester.pump();

    // A(10m)·B(12m)는 정북 일렬 배치라 나↔A·나↔B·A↔B 총 3쌍이 진입한다. 첫 방출은
    // 세 쌍을 pending에 등록만 한다(dwell=0에서도 확정은 다음 방출에서).
    nearby.add([userAt('A', 10), userAt('B', 12)]);
    await tester.pump();
    await tester.pump();

    // 같은 배치를 한 번 더 방출하면 세 pending이 dwell(0)을 충족해 한 배치로
    // 확정되어 펄스 3개가 동시에 온다.
    nearby.add([userAt('A', 10), userAt('B', 12)]);
    await tester.pump();
    await tester.pump();

    // 시퀀스 0/1/2 세 개의 펄스가 동시에 존재한다.
    expect(find.byKey(const ValueKey('encounter_pulse_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('encounter_pulse_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('encounter_pulse_2')), findsOneWidget);

    // pending ticker 방지: 세 애니메이션 모두 소멸시킨다.
    await tester.pump(const Duration(milliseconds: 1600));
  });
}
