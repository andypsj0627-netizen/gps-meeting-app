import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:gps_meeting_app/features/map/providers/location_provider.dart';
import 'package:gps_meeting_app/features/map/providers/nearby_users_provider.dart';
import 'package:gps_meeting_app/features/map/screens/map_screen.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/location_test_helpers.dart';

/// 주어진 fake 서비스로 MapScreen 을 감싼 테스트 앱을 펌프한다.
///
/// [nearbyStream]을 주면 근처 사용자 서비스를 그 스트림으로 override한다.
/// 지정하지 않으면, 실제 주기 타이머(pending timer)를 만들지 않도록 아무것도
/// 방출하지 않는 스트림으로 override한다.
Future<void> _pumpWithService(
  WidgetTester tester,
  FakeLocationService service, {
  Stream<List<NearbyUser>>? nearbyStream,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(service),
        nearbyUsersServiceProvider.overrideWithValue(
          ControlledNearbyUsersService(
            nearbyStream ?? const Stream<List<NearbyUser>>.empty(),
          ),
        ),
      ],
      child: MaterialApp(
        home: MapScreen(tileProvider: FakeTileProvider()),
      ),
    ),
  );
}

/// 주어진 스트림으로 MapScreen 을 감싼 테스트 앱을 펌프한다.
Future<void> _pumpMapScreen(
  WidgetTester tester,
  Stream<Position> stream,
) async {
  await _pumpWithService(tester, FakeLocationService(stream));
}

void main() {
  testWidgets('최초 위치 대기 중에는 로딩 인디케이터를 표시한다', (tester) async {
    // 아무 값도 방출하지 않는 스트림 → 계속 로딩 상태 유지.
    final controller = StreamController<Position>();
    addTearDown(controller.close);

    await _pumpMapScreen(tester, controller.stream);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('내 위치를 찾는 중...'), findsOneWidget);
  });

  testWidgets('권한 거부 시 안내 메시지와 재시도 버튼을 표시한다', (tester) async {
    await _pumpMapScreen(
      tester,
      Stream<Position>.error(
        const LocationException(
          LocationFailureKind.denied,
          '위치 권한이 거부되었습니다.',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('위치 권한이 거부되었습니다.'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry_button')), findsOneWidget);
    expect(find.text('재시도'), findsOneWidget);
    // 일시 거부이므로 설정 열기 버튼은 없다.
    expect(find.byKey(const ValueKey('open_settings_button')), findsNothing);
    // 로딩/지도는 표시되지 않는다.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('위치 수신 시 지도와 내 위치 마커를 표시한다', (tester) async {
    await _pumpMapScreen(
      tester,
      Stream.value(fakePosition(37.5665, 126.9780)),
    );
    // 스트림 이벤트를 처리한다.
    await tester.pump();
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const ValueKey('my_location_marker')), findsOneWidget);
    // follow 버튼이 표시된다.
    expect(find.byKey(const ValueKey('follow_button')), findsOneWidget);
    // 로딩/오류 UI 는 표시되지 않는다.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('retry_button')), findsNothing);
  });

  testWidgets('영구 거부 시 설정 열기 버튼을 표시하고 탭하면 openAppSettings를 호출한다',
      (tester) async {
    final service = FakeLocationService(
      Stream<Position>.error(
        const LocationException(
          LocationFailureKind.deniedForever,
          '위치 권한이 영구적으로 거부되었습니다.',
        ),
      ),
    );

    await _pumpWithService(tester, service);
    await tester.pump();

    final openSettings = find.byKey(const ValueKey('open_settings_button'));
    expect(openSettings, findsOneWidget);
    expect(find.byKey(const ValueKey('retry_button')), findsOneWidget);

    await tester.tap(openSettings);
    await tester.pump();

    expect(service.openAppSettingsCallCount, 1);
  });

  testWidgets('재시도 버튼 탭 시 로딩을 거쳐 위치 수신으로 복귀한다', (tester) async {
    // 재구독 가능한 broadcast 스트림으로 오류 → 재시도 → 위치 흐름을 재현한다.
    final controller = StreamController<Position>.broadcast();
    addTearDown(controller.close);
    final service = FakeLocationService(controller.stream);

    await _pumpWithService(tester, service);
    await tester.pump();

    // 초기 구독 후 오류 방출 → 오류 뷰.
    controller.addError(
      const LocationException(LocationFailureKind.unknown, '일시 오류'),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('retry_button')), findsOneWidget);

    // 재시도 → invalidate 후 로딩 인디케이터.
    await tester.tap(find.byKey(const ValueKey('retry_button')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 스트림이 위치 방출 → 지도 복귀.
    controller.add(fakePosition(37.5665, 126.9780));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('일시적 오류가 발생해도 이전 위치의 지도를 유지한다', (tester) async {
    final controller = StreamController<Position>();
    addTearDown(controller.close);

    await _pumpMapScreen(tester, controller.stream);
    await tester.pump();

    // 먼저 위치를 방출해 지도를 표시한다.
    controller.add(fakePosition(37.5665, 126.9780));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FlutterMap), findsOneWidget);

    // 이후 오류가 방출되어도 지도가 unmount되지 않는다(이전 데이터 보존).
    controller.addError(
      const LocationException(LocationFailureKind.unknown, '일시 오류'),
    );
    await tester.pump();
    expect(find.byType(FlutterMap), findsOneWidget);
    // 오류 뷰가 지도를 밀어내지 않는다.
    expect(find.byKey(const ValueKey('retry_button')), findsNothing);
  });

  testWidgets('가상 근처 사용자 A/B/C 마커를 표시하고 새 방출 시 위치를 갱신한다',
      (tester) async {
    // 실제 주기 타이머 대신 직접 제어하는 스트림으로 근처 사용자 방출을 재현한다.
    // 단일 구독 컨트롤러는 리스너가 붙기 전 이벤트도 버퍼링하므로 유실이 없다.
    final nearby = StreamController<List<NearbyUser>>();
    addTearDown(nearby.close);

    await _pumpWithService(
      tester,
      FakeLocationService(Stream.value(fakePosition(37.5665, 126.9780))),
      nearbyStream: nearby.stream,
    );
    // 위치 수신 → 지도 표시 → nearbyUsersProvider가 근처 스트림을 구독한다.
    await tester.pump();
    await tester.pump();

    final users = [
      const NearbyUser(
          id: 'fake_A', name: 'A', position: LatLng(37.5670, 126.9785)),
      const NearbyUser(
          id: 'fake_B', name: 'B', position: LatLng(37.5660, 126.9790)),
      const NearbyUser(
          id: 'fake_C', name: 'C', position: LatLng(37.5655, 126.9775)),
    ];
    nearby.add(users);
    await tester.pump();
    await tester.pump();

    // 마커 key 는 사용자 id 기반이다.
    expect(
        find.byKey(const ValueKey('nearby_user_marker_fake_A')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('nearby_user_marker_fake_B')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('nearby_user_marker_fake_C')),
        findsOneWidget);
    // 이니셜이 마커에 렌더링된다.
    expect(find.text('A'), findsOneWidget);
    // 내 위치 마커는 그대로 유지된다.
    expect(find.byKey(const ValueKey('my_location_marker')), findsOneWidget);

    // 새 리스트 방출 시 A의 마커 위치가 갱신된다.
    const movedA = LatLng(37.5699, 126.9788);
    nearby.add([
      const NearbyUser(id: 'fake_A', name: 'A', position: movedA),
      users[1],
      users[2],
    ]);
    await tester.pump();
    await tester.pump();

    // flutter_map 8.x의 Marker는 Widget이 아니므로, 근처 사용자 MarkerLayer를
    // 찾아 그 안의 A 마커 좌표가 갱신되었는지 확인한다.
    const keyA = ValueKey('nearby_user_marker_fake_A');
    final nearbyLayer = tester
        .widgetList<MarkerLayer>(find.byType(MarkerLayer))
        .firstWhere((layer) => layer.markers.any((m) => m.key == keyA));
    final markerA = nearbyLayer.markers.firstWhere((m) => m.key == keyA);
    expect(markerA.point, movedA);
  });
}
