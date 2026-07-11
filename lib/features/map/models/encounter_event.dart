import '../services/encounter_detector.dart';
import 'nearby_user.dart';

/// 두 참가자 사이에 "조우(만남)"가 성립한 순간을 나타내는 불변 모델.
///
/// [EncounterDetector]가 진입 반경 안으로 들어온 쌍을 감지할 때마다 하나씩
/// 만들어 방출한다. 참가자에는 "나"([EncounterDetector.selfId])도 포함되므로,
/// 나↔상대의 조우뿐 아니라 타인끼리의 조우도 같은 모델로 표현된다. 화면 계층은
/// 이 이벤트를 받아 스낵바 등으로 알린다.
///
/// 참가자 순서는 생성 시 정규화된다: 나(selfId)가 포함되면 항상 [a]에 오고,
/// 타인끼리면 id 정렬순으로 [a]/[b]가 정해진다. 같은 쌍이면 입력 순서와
/// 무관하게 항상 같은 배치가 된다.
///
/// 이벤트는 "발생한 순간" 그 자체를 가리키는 식별자 의미론을 가진다. 같은 쌍이
/// 다시 만나면 별개의 조우이므로, 구조적 동등성(==/hashCode)을 두면 오히려 서로
/// 다른 조우를 같게 취급하는 함정이 된다. 그래서 동등성은 참조 동일성으로 남긴다.
class EncounterEvent {
  factory EncounterEvent({
    required NearbyUser a,
    required NearbyUser b,
    required double distanceMeters,
    required DateTime timestamp,
  }) {
    // 정규화: 나(selfId)를 항상 a로, 타인끼리면 id 정렬순으로 놓는다.
    final swap = b.id == EncounterDetector.selfId ||
        (a.id != EncounterDetector.selfId && a.id.compareTo(b.id) > 0);
    return EncounterEvent._(
      a: swap ? b : a,
      b: swap ? a : b,
      distanceMeters: distanceMeters,
      timestamp: timestamp,
    );
  }

  const EncounterEvent._({
    required this.a,
    required this.b,
    required this.distanceMeters,
    required this.timestamp,
  });

  /// 조우한 첫 번째 참가자. 나(selfId)가 포함된 조우라면 항상 나다.
  final NearbyUser a;

  /// 조우한 두 번째 참가자.
  final NearbyUser b;

  /// 이벤트 발생 시점의 두 참가자 사이 거리(m).
  final double distanceMeters;

  /// 이벤트가 발생한 시각.
  final DateTime timestamp;

  /// 이 조우에 나([EncounterDetector.selfId])가 포함되어 있는지 여부.
  ///
  /// 정규화로 나는 항상 [a]에 오므로 [a]만 확인하면 된다.
  bool get involvesMe => a.id == EncounterDetector.selfId;

  /// 나를 제외한 상대 참가자.
  ///
  /// [involvesMe]가 true일 때만 의미가 있다. 타인끼리의 조우에서는 "나를 제외한
  /// 상대"라는 개념이 성립하지 않으므로 그냥 [b]를 반환한다 — 호출 전에
  /// [involvesMe]를 먼저 확인할 것.
  NearbyUser get partner => b;

  @override
  String toString() => 'EncounterEvent($a, $b, $distanceMeters, $timestamp)';
}
