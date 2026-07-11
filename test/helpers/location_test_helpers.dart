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

/// 테스트용 위치 좌표를 만드는 헬퍼.
Position fakePosition(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// 주입한 스트림을 그대로 반환하는 fake 위치 서비스.
///
/// [openAppSettings]/[openLocationSettings] 호출 여부를 기록하여
/// 오류 뷰의 조치 버튼 동작을 검증할 수 있다.
class FakeLocationService implements LocationService {
  FakeLocationService(this._stream);

  final Stream<Position> _stream;

  /// [openAppSettings] 호출 횟수.
  int openAppSettingsCallCount = 0;

  /// [openLocationSettings] 호출 횟수.
  int openLocationSettingsCallCount = 0;

  @override
  Stream<Position> getPositionStream() => _stream;

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCallCount++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCallCount++;
    return true;
  }
}

/// 고정된 시뮬레이션 사용자 목록을 반환하는 fake notifier.
///
/// 타이머/난수/Firestore 없이 마커 UI를 결정적으로 검증하기 위해 사용한다.
class FakeNearbyUsersNotifier extends NearbyUsersNotifier {
  FakeNearbyUsersNotifier(this._users);

  final List<SimulatedUser> _users;

  @override
  List<SimulatedUser> build() => _users;
}

/// 테스트용 [SimulatedUser]를 만드는 헬퍼.
SimulatedUser fakeSimUser(
  String id, {
  String name = '테스트',
  int age = 20,
  String gender = 'm',
  LatLng position = const LatLng(0, 0),
  bool encountered = false,
}) {
  return SimulatedUser(
    profile: NearbyUser(id: id, name: name, age: age, gender: gender),
    position: position,
    encountered: encountered,
  );
}

/// 네트워크 요청 없이 투명 이미지를 반환하는 테스트용 타일 프로바이더.
///
/// 실제 OSM 타일을 요청하면 위젯 테스트가 불안정해지므로 이를 우회한다.
class FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(TileProvider.transparentImage);
  }
}

/// [MapScreen]을 ProviderScope/MaterialApp 스캐폴드로 감싸 펌프한다.
///
/// 위치 서비스는 [locationService]로, 시뮬레이션 사용자는 [nearbyUsers]로
/// override한다(기본 빈 목록이라 Firestore/타이머에 닿지 않는다). 타일은
/// 네트워크에 닿지 않도록 [FakeTileProvider]로 고정한다. 펌프 타이밍은
/// 호출자가 제어한다(이 함수는 pumpWidget만 수행).
Future<void> pumpMapScreen(
  WidgetTester tester, {
  required LocationService locationService,
  List<SimulatedUser> nearbyUsers = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(locationService),
        nearbyUsersProvider
            .overrideWith(() => FakeNearbyUsersNotifier(nearbyUsers)),
      ],
      child: MaterialApp(
        home: MapScreen(tileProvider: FakeTileProvider()),
      ),
    ),
  );
}
