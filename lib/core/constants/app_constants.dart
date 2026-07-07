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

  /// OSRM 공개 데모 서버의 라우팅 엔드포인트 (foot 프로필).
  static const String osrmRouteBaseUrl =
      'https://router.project-osrm.org/route/v1/foot';

  /// 가상 사용자 시뮬레이션 속도 배율.
  ///
  /// 1.0이 실제 보행 속도(1.1~1.5m/s). 테스트 단계에서는 움직임을 빠르게
  /// 확인하기 위해 배율을 올려둔다. 출시 전 1.0으로 되돌릴 것.
  static const double simulationSpeedMultiplier = 5.0;
}
