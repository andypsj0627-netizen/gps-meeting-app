import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/location_test_helpers.dart';

/// 영향 반경 원(_InfluenceCircleLayer)이 내 위치와 근처 사용자마다 원을 그리는지
/// 검증한다. 색/투명도 같은 시각 값은 검증하지 않고(의도적 생략), 원의 개수와
/// 미터 반경 사용 여부만 확인한다.
void main() {
  testWidgets('내 위치만 있으면 영향 반경 원이 1개(내 원)만 그려진다', (tester) async {
    await pumpMapScreenWithService(
      tester,
      FakeLocationService(Stream.value(fakePosition(37.5665, 126.9780))),
    );
    await tester.pump();
    await tester.pump();

    final layer = tester.widget<CircleLayer>(find.byType(CircleLayer));
    expect(layer.circles, hasLength(1));
    // 반경은 미터로 해석되어야 한다(useRadiusInMeter).
    expect(layer.circles.single.useRadiusInMeter, isTrue);
  });

  testWidgets('근처 사용자 3명이면 원이 4개(사용자 3 + 내 위치 1) 그려진다', (tester) async {
    final nearby = StreamController<List<NearbyUser>>();
    addTearDown(nearby.close);

    await pumpMapScreenWithService(
      tester,
      FakeLocationService(Stream.value(fakePosition(37.5665, 126.9780))),
      nearbyStream: nearby.stream,
    );
    // 위치 수신 → 지도 표시 → nearbyUsersProvider가 근처 스트림을 구독한다.
    await tester.pump();
    await tester.pump();

    nearby.add(const [
      NearbyUser(id: 'fake_A', name: 'A', position: LatLng(37.5670, 126.9785)),
      NearbyUser(id: 'fake_B', name: 'B', position: LatLng(37.5660, 126.9790)),
      NearbyUser(id: 'fake_C', name: 'C', position: LatLng(37.5655, 126.9775)),
    ]);
    await tester.pump();
    await tester.pump();

    final layer = tester.widget<CircleLayer>(find.byType(CircleLayer));
    expect(layer.circles, hasLength(4));
  });
}
