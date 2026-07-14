/// 앱 전역에서 사용하는 상수 모음.
///
/// 인스턴스화할 필요가 없으므로 private 생성자로 막아둔다.
class AppConstants {
  const AppConstants._();

  /// 앱 이름 (AppBar 등 UI에 표시).
  static const String appName = 'GPS 모임';

  /// 지도 초기 줌 레벨.
  static const double initialZoom = 16;

  /// 지도 최소 줌 레벨. 카메라 이동(버튼/스크롤/핀치)이 이 아래로 내려가지 않는다.
  static const double minZoom = 3;

  /// 지도 최대 줌 레벨. OSM 타일이 제공되는 상한(19)에 맞춘다.
  static const double maxZoom = 19;

  /// OSM 타일 정책상 요구되는 User-Agent 패키지명.
  static const String userAgentPackageName = 'com.example.gps_meeting_app';

  /// OpenStreetMap 타일 URL 템플릿.
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// OSRM 공개 서버의 라우팅 엔드포인트 (보행자 프로필).
  ///
  /// router.project-osrm.org 데모는 자동차 프로필만 호스팅해 URL의 foot이
  /// 무시된다(마커가 터널로 산을 통과하는 원인이었음). FOSSGIS 인스턴스는
  /// 실제 보행자 프로필을 제공한다 — 경로 세그먼트(/routed-foot/)가 프로필을
  /// 결정하고 뒤의 /foot은 형식상 자리표시자다.
  static const String osrmRouteBaseUrl =
      'https://routing.openstreetmap.de/routed-foot/route/v1/foot';

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

  /// 개발 단계에서 로그인 화면을 건너뛰고 바로 지도로 진입하기 위한 임시 플래그.
  ///
  /// false면 앱 시작 시 로그인 화면 없이 곧바로 지도('/')가 뜨고, 인증 배선 자체가
  /// 활성화되지 않는다. 로그인 화면 코드는 삭제하지 않고 이 플래그로 우회만 한다.
  /// 출시 전(또는 로그인 화면 디자인 작업을 재개할 때) true로 되돌릴 것.
  static const bool requireLogin = false;
}
