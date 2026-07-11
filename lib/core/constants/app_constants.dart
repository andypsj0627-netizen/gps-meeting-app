/// 앱 전역에서 사용하는 상수 모음.
///
/// 인스턴스화할 필요가 없으므로 private 생성자로 막아둔다.
class AppConstants {
  const AppConstants._();

  /// 앱 이름 (AppBar 등 UI에 표시).
  static const String appName = 'GPS 모임';

  /// 지도 초기 줌 레벨.
  static const double initialZoom = 16;

  /// OSM 타일 정책상 요구되는 User-Agent 패키지명.
  static const String userAgentPackageName = 'com.example.gps_meeting_app';

  /// OpenStreetMap 타일 URL 템플릿.
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// 조우(만남)로 판정하는 거리 임계값(미터).
  ///
  /// 시뮬레이션 사용자가 내 위치 또는 다른 시뮬레이션 사용자와 이 거리 이내로
  /// 접근하면 조우한 것으로 간주한다.
  static const double encounterRadiusMeters = 30;
}
