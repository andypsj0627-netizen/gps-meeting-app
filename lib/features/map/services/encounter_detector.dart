import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../models/encounter_event.dart';
import '../models/nearby_user.dart';

/// 내 위치와 근처 사용자 목록으로부터 "조우(만남)"를 감지하는 순수 로직 클래스.
///
/// 네트워크/타이머/Riverpod에 의존하지 않으므로 테스트에서 결정적으로 검증할 수
/// 있다. 상태(현재 조우 중인 사용자 id 집합)만 내부에 들고, [update]를 반복
/// 호출하며 새로 성립한 조우 이벤트를 뽑아낸다.
///
/// 진입/해제에 서로 다른 반경([enterRadius] < [exitRadius])을 두어
/// 히스테리시스를 구현한다. 경계선 부근에서 사용자가 미세하게 움직여도 진입/이탈이
/// 반복되며 알림이 연쇄로 터지지 않는다. 한 번 조우한 상대는 [exitRadius] 밖으로
/// 충분히 멀어져 상태가 해제된 뒤 다시 [enterRadius] 안으로 들어와야 재발생한다.
class EncounterDetector {
  EncounterDetector({
    this.enterRadius = AppConstants.encounterEnterRadius,
    this.exitRadius = AppConstants.encounterExitRadius,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        assert(
          enterRadius < exitRadius,
          '진입 반경은 해제 반경보다 작아야 히스테리시스가 성립한다.',
        );

  /// 이 거리(m) 이내로 들어오면 조우로 판정한다.
  final double enterRadius;

  /// 조우 상태인 사용자가 이 거리(m) 이상 벗어나야 상태를 해제한다.
  final double exitRadius;

  /// 이벤트 타임스탬프 생성기. 테스트에서 결정적 시각을 주입하기 위해 분리했다.
  final DateTime Function() _now;

  /// 서브미터 거리 비교를 위해 미터 반올림을 끈 거리 계산기.
  /// FakeNearbyUsersService와 동일한 설정을 사용한다.
  static const Distance _distance = Distance(roundResult: false);

  /// 현재 "조우 중"으로 판정된 사용자 id 집합.
  ///
  /// 이 집합에 든 사용자는 [exitRadius] 밖으로 나가기 전까지 이벤트를 재발생시키지
  /// 않는다.
  final Set<String> _active = <String>{};

  /// 최신 내 위치와 사용자 목록으로 조우 상태를 갱신하고, 이번 호출에서 새로
  /// 발생한 조우 이벤트 목록을 반환한다.
  ///
  /// 판정 규칙:
  /// - 조우 중이 아닌 사용자가 [enterRadius] 이내 → 이벤트 생성 + 집합에 추가
  /// - 조우 중인 사용자가 [exitRadius] 이상 → 집합에서 제거(이벤트 없음)
  /// - 이번 [users] 목록에 없는 id → 집합에서 제거(사라진 사용자 상태 초기화)
  List<EncounterEvent> update(LatLng myPosition, List<NearbyUser> users) {
    final events = <EncounterEvent>[];
    final presentIds = <String>{};

    for (final user in users) {
      presentIds.add(user.id);
      final distance = _distance.distance(myPosition, user.position);
      final isActive = _active.contains(user.id);

      if (isActive) {
        // 이미 조우 중 — 해제 반경 밖으로 나가면 상태를 푼다(이벤트 없음).
        if (distance >= exitRadius) {
          _active.remove(user.id);
        }
      } else {
        // 조우 중이 아님 — 진입 반경 안으로 들어오면 이벤트를 발생시킨다.
        if (distance <= enterRadius) {
          _active.add(user.id);
          events.add(
            EncounterEvent(
              user: user,
              distanceMeters: distance,
              timestamp: _now(),
            ),
          );
        }
      }
    }

    // 이번 목록에서 사라진 사용자는 상태를 초기화한다. 다시 나타나 진입 반경
    // 안으로 들어오면 새 이벤트로 취급된다.
    _active.removeWhere((id) => !presentIds.contains(id));

    return events;
  }
}
