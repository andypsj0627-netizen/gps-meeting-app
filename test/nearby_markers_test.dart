import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/map/providers/nearby_users_provider.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/location_test_helpers.dart';

const _distance = Distance();
const _center = LatLng(37.5665, 126.9780);

/// 조우/비조우 사용자 마커를 얹은 MapScreen을 펌프한다.
Future<void> _pump(WidgetTester tester, List<SimulatedUser> users) async {
  await pumpMapScreen(
    tester,
    locationService: FakeLocationService(
      Stream.value(fakePosition(_center.latitude, _center.longitude)),
    ),
    nearbyUsers: users,
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('시뮬레이션 사용자 마커 5개가 표시된다', (tester) async {
    final users = [
      for (var i = 1; i <= 5; i++)
        fakeSimUser('user$i',
            position: _distance.offset(_center, 40.0 * i, 60.0 * i)),
    ];

    await _pump(tester, users);

    for (var i = 1; i <= 5; i++) {
      expect(find.byKey(ValueKey('nearby_user_user$i')), findsOneWidget);
    }
  });

  testWidgets('조우한 마커를 탭하면 프로필 바텀시트가 열린다', (tester) async {
    final users = [
      fakeSimUser(
        'userE',
        name: '이서연',
        age: 25,
        gender: 'f',
        position: _distance.offset(_center, 120, 90),
        encountered: true,
      ),
    ];

    await _pump(tester, users);

    await tester.tap(find.byKey(const ValueKey('nearby_user_userE')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile_sheet')), findsOneWidget);
    expect(find.text('이서연'), findsOneWidget);
    expect(find.text('ID: userE'), findsOneWidget);
    expect(find.text('나이: 25'), findsOneWidget);
    expect(find.text('성별: 여성'), findsOneWidget);
  });

  testWidgets('조우 전 마커를 탭하면 바텀시트가 열리지 않는다', (tester) async {
    final users = [
      fakeSimUser(
        'userN',
        name: '김민준',
        position: _distance.offset(_center, 120, 90),
      ),
    ];

    await _pump(tester, users);

    await tester.tap(find.byKey(const ValueKey('nearby_user_userN')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile_sheet')), findsNothing);
    expect(find.text('김민준'), findsNothing);
  });
}
