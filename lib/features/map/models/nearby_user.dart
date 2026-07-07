import 'package:latlong2/latlong.dart';

/// 지도에 표시되는 "근처 사용자" 한 명을 나타내는 불변 모델.
///
/// Phase 2 단계에서는 [id]/[name]/[position]만으로 충분하다. 프로필 사진,
/// 거리, 관심 표시 여부 등은 이후 Phase에서 필드로 확장한다.
class NearbyUser {
  const NearbyUser({
    required this.id,
    required this.name,
    required this.position,
  });

  /// 사용자 식별자. 마커 key 및 동등성 비교의 기준이 된다.
  final String id;

  /// 화면에 표시할 이름/이니셜. 현재 시뮬레이션에서는 'A'/'B'/'C'.
  final String name;

  /// 현재 위치.
  final LatLng position;

  @override
  bool operator ==(Object other) =>
      other is NearbyUser &&
      other.id == id &&
      other.name == name &&
      other.position == position;

  @override
  int get hashCode => Object.hash(id, name, position);

  @override
  String toString() => 'NearbyUser($id, $name, $position)';
}
