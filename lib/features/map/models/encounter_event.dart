import 'nearby_user.dart';

/// 근처 사용자와 "조우(만남)"가 성립한 순간을 나타내는 불변 모델.
///
/// [EncounterDetector]가 진입 반경 안으로 들어온 상대를 감지할 때마다 하나씩
/// 만들어 방출한다. 화면 계층은 이 이벤트를 받아 스낵바 등으로 알린다.
///
/// 이벤트는 "발생한 순간" 그 자체를 가리키는 식별자 의미론을 가진다. 같은 상대와
/// 다시 만나면 별개의 조우이므로, 구조적 동등성(==/hashCode)을 두면 오히려 서로
/// 다른 조우를 같게 취급하는 함정이 된다. 그래서 동등성은 참조 동일성으로 남긴다.
class EncounterEvent {
  const EncounterEvent({
    required this.user,
    required this.distanceMeters,
    required this.timestamp,
  });

  /// 조우한 상대.
  final NearbyUser user;

  /// 이벤트 발생 시점의 나와 상대 사이 거리(m).
  final double distanceMeters;

  /// 이벤트가 발생한 시각.
  final DateTime timestamp;

  @override
  String toString() => 'EncounterEvent($user, $distanceMeters, $timestamp)';
}
