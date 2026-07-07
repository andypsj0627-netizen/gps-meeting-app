import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:gps_meeting_app/features/map/providers/location_provider.dart';
import 'package:gps_meeting_app/features/map/providers/nearby_users_provider.dart';
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

/// 주입한 스트림을 그대로 반환하는 fake 근처 사용자 서비스.
///
/// 실제 주기 타이머 대신 테스트가 직접 제어하는 [StreamController] 스트림을
/// 주입하여, 위젯 테스트에서 pending timer 오류 없이 마커 갱신을 검증한다.
class ControlledNearbyUsersService implements NearbyUsersService {
  ControlledNearbyUsersService(this._stream);

  final Stream<List<NearbyUser>> _stream;

  @override
  Stream<List<NearbyUser>> watchNearbyUsers(LatLng center) => _stream;
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
