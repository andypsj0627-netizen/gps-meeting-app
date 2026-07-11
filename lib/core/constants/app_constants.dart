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

  /// 조우(만남) 진입 판정 반경(m).
  ///
  /// 근처 사용자가 내 위치 기준 이 거리 이내로 들어오면 조우 이벤트를 발생시킨다.
  ///
  /// 테스트 단계에서는 가상 사용자가 우연히 지나가는 조우를 빨리 관찰하기 위해
  /// 반경을 넓혀둔다. 출시 전 15.0으로 되돌릴 것.
  static const double encounterEnterRadius = 60.0;

  /// 조우 해제 판정 반경(m).
  ///
  /// 조우 상태인 사용자가 이 거리 밖으로 나가야 상태를 해제한다. 진입 반경보다
  /// 넉넉하게 두어(히스테리시스), 경계선 부근에서 진입/이탈이 반복될 때 알림이
  /// 연쇄로 터지는 것을 막는다. 해제된 뒤 다시 진입하면 이벤트가 재발생한다.
  ///
  /// 진입 반경과 마찬가지로 테스트 단계 확대값. 출시 전 40.0으로 되돌릴 것.
  static const double encounterExitRadius = 100.0;
}
