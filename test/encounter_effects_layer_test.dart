import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';

import 'helpers/location_test_helpers.dart';

void main() {
  testWidgets('근처 사용자가 진입 반경 이내로 들어오면 펄스 마커가 나타난다',
      (tester) async {
    final nearby = StreamController<List<NearbyUser>>();
    addTearDown(nearby.close);

    await pumpMapScreenWithService(
      tester,
      FakeLocationService(Stream.value(fakePosition(37.5665, 126.9780))),
      nearbyStream: nearby.stream,
    );
    await tester.pump();
    await tester.pump();

    // 진입 반경 이내(10m ≤ 15m)로 들어오면 나↔A 조우 1건이 성립한다.
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
    );
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
    );
    await tester.pump();
    await tester.pump();

    // A(10m)·B(12m)는 정북 일렬 배치라 나↔A·나↔B·A↔B 총 3건이 한 배치로 온다.
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
