import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../models/encounter_event.dart';
import '../models/nearby_user.dart';

/// 내 위치와 근처 사용자 목록으로부터 "조우(만남)"를 감지하는 순수 로직 클래스.
///
/// 나를 [selfId]라는 예약 id의 참가자로 포함시켜, 모든 참가자의 무순서 쌍에
/// 대해 거리를 판정한다. 따라서 나↔상대의 조우뿐 아니라 타인끼리의 조우도
/// 감지한다. 네트워크/타이머/Riverpod에 의존하지 않으므로 테스트에서 결정적으로
/// 검증할 수 있다. 상태(현재 조우 중인 쌍 키 집합)만 내부에 들고, [update]를
/// 반복 호출하며 새로 성립한 조우 이벤트를 뽑아낸다.
///
/// 진입/해제에 서로 다른 반경([enterRadius] < [exitRadius])을 두어
/// 히스테리시스를 구현한다. 경계선 부근에서 참가자가 미세하게 움직여도 진입/이탈이
/// 반복되며 알림이 연쇄로 터지지 않는다. 한 번 조우한 쌍은 [exitRadius] 밖으로
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

  /// "나"를 참가자로 표현할 때 쓰는 예약 id.
  ///
  /// 가상 사용자 id는 'fake_X' 형식이므로 충돌하지 않는다.
  static const String selfId = 'me';

  /// 이 거리(m) 이내로 들어오면 조우로 판정한다.
  final double enterRadius;

  /// 조우 상태인 쌍이 이 거리(m) 이상 벌어져야 상태를 해제한다.
  final double exitRadius;

  /// 이벤트 타임스탬프 생성기. 테스트에서 결정적 시각을 주입하기 위해 분리했다.
  final DateTime Function() _now;

  /// 서브미터 거리 비교를 위해 미터 반올림을 끈 거리 계산기.
  /// FakeNearbyUsersService와 동일한 설정을 사용한다.
  static const Distance _distance = Distance(roundResult: false);

  /// 현재 "조우 중"으로 판정된 쌍 키 집합.
  ///
  /// 키는 [_pairKey]로 정규화한 문자열이다. 이 집합에 든 쌍은 [exitRadius]
  /// 밖으로 벌어지기 전까지 이벤트를 재발생시키지 않는다.
  final Set<String> _active = <String>{};

  /// 두 id를 정렬해 무순서 쌍의 정규화 키를 만든다. (a,b)와 (b,a)가 같은 키다.
  static String _pairKey(String x, String y) =>
      x.compareTo(y) <= 0 ? '$x|$y' : '$y|$x';

  /// 최신 내 위치와 사용자 목록으로 조우 상태를 갱신하고, 이번 호출에서 새로
  /// 발생한 조우 이벤트 목록을 반환한다.
  ///
  /// 판정 규칙 (나를 포함한 모든 무순서 쌍에 대해):
  /// - 조우 중이 아닌 쌍이 [enterRadius] 이내 → 이벤트 생성 + 집합에 추가
  /// - 조우 중인 쌍이 [exitRadius] 이상 → 집합에서 제거(이벤트 없음)
  /// - 어느 한쪽이라도 이번 목록에 없는 쌍 → 집합에서 제거(사라진 쌍 상태 초기화)
  List<EncounterEvent> update(LatLng myPosition, List<NearbyUser> users) {
    // 나도 하나의 참가자로 만들어 쌍 판정에 포함시킨다.
    final participants = <NearbyUser>[
      NearbyUser(id: selfId, name: '나', position: myPosition),
      ...users,
    ];
    final events = <EncounterEvent>[];
    final presentKeys = <String>{};

    for (var i = 0; i < participants.length; i++) {
      for (var j = i + 1; j < participants.length; j++) {
        final a = participants[i];
        final b = participants[j];
        final key = _pairKey(a.id, b.id);
        presentKeys.add(key);
        final distance = _distance.distance(a.position, b.position);

        if (_active.contains(key)) {
          // 이미 조우 중인 쌍 — 해제 반경 밖으로 벌어지면 상태를 푼다(이벤트 없음).
          if (distance >= exitRadius) {
            _active.remove(key);
          }
        } else {
          // 조우 중이 아닌 쌍 — 진입 반경 안으로 들어오면 이벤트를 발생시킨다.
          if (distance <= enterRadius) {
            _active.add(key);
            events.add(
              EncounterEvent(
                a: a,
                b: b,
                distanceMeters: distance,
                timestamp: _now(),
              ),
            );
          }
        }
      }
    }

    // 어느 한쪽이라도 이번 목록에서 사라진 쌍은 상태를 초기화한다. 다시 나타나
    // 진입 반경 안으로 들어오면 새 이벤트로 취급된다.
    _active.removeWhere((key) => !presentKeys.contains(key));

    return events;
  }

  /// 현재 조우 활성 상태인 쌍에 등장하는 사용자 id 집합(나 [selfId] 제외).
  ///
  /// [_active]의 각 키는 [_pairKey]로 정규화된 'x|y' 꼴이며 항상 두 요소로
  /// 이루어진다. 각 키를 '|'로 나눠 [selfId]를 뺀 상대 id들을 모은다. 나↔상대
  /// 조우면 상대 id가, 타인끼리 조우면 두 사용자 id가 모두 담긴다. 해금 여부는
  /// 이 집합에서 파생하므로, [exitRadius] 밖으로 벌어지거나 목록에서 사라져
  /// 쌍이 [_active]에서 빠지면 해당 id도 자동으로 사라진다.
  Set<String> get activeUserIds {
    final ids = <String>{};
    for (final key in _active) {
      for (final id in key.split('|')) {
        if (id != selfId) ids.add(id);
      }
    }
    return ids;
  }
}
