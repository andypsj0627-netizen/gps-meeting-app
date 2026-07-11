import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// geolocator의 [Position]을 flutter_map/latlong2 좌표계로 잇는 확장.
extension PositionLatLng on Position {
  /// 위도/경도만 뽑아 [LatLng]로 변환한다.
  LatLng get latLng => LatLng(latitude, longitude);
}
