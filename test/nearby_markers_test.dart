import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:gps_meeting_app/features/map/providers/encounter_provider.dart';
import 'package:gps_meeting_app/features/map/services/encounter_detector.dart';

import 'helpers/location_test_helpers.dart';

/// 내 위치(= [testCenter])에 서서, 근처 사용자 스트림을 직접 제어하는 MapScreen을
/// 펌프하고, 컨트롤러를 돌려준다. 스트림에 사용자를 밀어 넣어 마커/조우를 만든다.
Future<StreamController<List<NearbyUser>>> _pump(WidgetTester tester) async {
  final nearby = StreamController<List<NearbyUser>>();
  addTearDown(nearby.close);
  await pumpMapScreenWithService(
    tester,
    FakeLocationService(
      Stream.value(fakePosition(testCenter.latitude, testCenter.longitude)),
    ),
    nearbyStream: nearby.stream,
    // dwell을 없애 벽시계를 전진시키지 않고도 조우를 확정한다. 단 dwell=0이어도
    // 진입 방출은 pending만 등록되고 다음 방출에서 확정되므로, 해금을 관측하는
    // 테스트는 같은 사용자를 두 번 방출해야 한다.
    extraOverrides: [
      encounterDetectorProvider.overrideWith(
        (ref) => EncounterDetector(
          enterRadius: 60,
          exitRadius: 100,
          dwell: Duration.zero,
        ),
      ),
    ],
  );
  // 위치 수신 → 지도 표시 → nearbyUsersProvider가 근처 스트림을 구독한다.
  await tester.pump();
  await tester.pump();
  return nearby;
}

void main() {
  testWidgets('시뮬레이션 사용자 마커 5개가 표시된다', (tester) async {
    final nearby = await _pump(tester);

    // 5명을 서로 다른 거리/방위로 배치한다(대부분 조우 반경 밖).
    final users = [
      for (var i = 1; i <= 5; i++)
        userAt('user$i', 80.0 * i, center: testCenter),
    ];
    nearby.add(users);
    await tester.pump();
    await tester.pump();

    for (var i = 1; i <= 5; i++) {
      expect(
        find.byKey(ValueKey('nearby_user_marker_user$i')),
        findsOneWidget,
      );
    }
  });

  testWidgets('조우한 마커를 탭하면 프로필 바텀시트가 열린다', (tester) async {
    final nearby = await _pump(tester);

    // 진입 반경 이내(55m)에 배치 → 조우 이벤트로 해금된다. 내 위치 마커와
    // 화면에서 겹치지 않도록 동쪽으로 충분히 떨어뜨려 탭이 정확히 이 마커에 닿게 한다.
    final user = NearbyUser(
      id: 'userE',
      name: '이서연',
      age: 25,
      gender: 'f',
      position: testDistance.offset(testCenter, 55, 90),
    );
    // 첫 방출은 pending 등록만 된다.
    nearby.add([user]);
    await tester.pump();
    await tester.pump();
    // 같은 사용자를 한 번 더 방출 → 다음 방출에서 dwell 충족되어 조우 확정+해금.
    nearby.add([user]);
    await tester.pump();
    await tester.pump();

    // 해금된 마커를 탭하면 프로필 시트가 열린다.
    await tester.tap(find.byKey(const ValueKey('nearby_user_marker_userE')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile_sheet')), findsOneWidget);
    expect(find.text('이서연'), findsOneWidget);
    expect(find.text('ID: userE'), findsOneWidget);
    expect(find.text('나이: 25'), findsOneWidget);
    expect(find.text('성별: 여성'), findsOneWidget);
  });

  testWidgets('조우로 해금된 마커가 멀어지면 재잠금되고 탭해도 프로필이 안 열린다',
      (tester) async {
    final nearby = await _pump(tester);

    // 진입 반경 이내(55m)에 배치 → 조우 이벤트로 해금된다.
    final entering = NearbyUser(
      id: 'userE',
      name: '이서연',
      age: 25,
      gender: 'f',
      position: testDistance.offset(testCenter, 55, 90),
    );
    // 첫 방출은 pending 등록만 되므로, 같은 위치를 두 번 방출해 해금을 확정시킨다.
    nearby.add([entering]);
    await tester.pump();
    await tester.pump();
    nearby.add([entering]);
    await tester.pump();
    await tester.pump();
    // 해금이 확정되어 마커가 트리에 존재한다.
    expect(
      find.byKey(const ValueKey('nearby_user_marker_userE')),
      findsOneWidget,
    );

    // 이탈 반경(100m) 밖(200m)으로 같은 id를 이동 → 조우 활성 해제 → 재잠금.
    // 재잠금은 dwell과 무관하므로 한 번 방출로 active에서 즉시 빠진다.
    final leaving = NearbyUser(
      id: 'userE',
      name: '이서연',
      age: 25,
      gender: 'f',
      position: testDistance.offset(testCenter, 200, 90),
    );
    nearby.add([leaving]);
    await tester.pump();
    await tester.pump();

    // 재잠금된 마커를 탭해도 프로필 시트가 열리지 않아야 한다.
    await tester.tap(find.byKey(const ValueKey('nearby_user_marker_userE')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile_sheet')), findsNothing);
  });

  testWidgets('조우 전(반경 밖) 마커를 탭하면 바텀시트가 열리지 않는다', (tester) async {
    final nearby = await _pump(tester);

    // 진입 반경(60m) 밖(120m)에 배치 → 해금되지 않는다.
    final user = NearbyUser(
      id: 'userN',
      name: '김민준',
      age: 27,
      gender: 'm',
      position: testDistance.offset(testCenter, 120, 0),
    );
    nearby.add([user]);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('nearby_user_marker_userN')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile_sheet')), findsNothing);
    expect(find.text('김민준'), findsNothing);
  });
}
