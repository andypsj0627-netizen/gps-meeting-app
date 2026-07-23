import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/map/models/encounter_event.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:gps_meeting_app/features/map/services/encounter_detector.dart';

import 'helpers/location_test_helpers.dart';

void main() {
  // 좌표 생성과 조우 판정의 기준점. userAt의 기본 중심과 동일하다.
  final me = testCenter;

  // 명시적으로 주입하는 dwell. AppConstants 기본값에 의존하지 않는다.
  const dwell = Duration(seconds: 10);

  /// 가변 시각 클로저로 구동하는 detector와 그 시계를 함께 만든다.
  ///
  /// 반경/체류시간은 명시적으로 15/40/10초를 주입한다. AppConstants의 값은
  /// 테스트 단계에서 관찰 편의를 위해 조정될 수 있으므로 기본값에 의존하지 않는다.
  /// 반환한 [_Clock]의 시각을 전진시키면 다음 update가 그 시각을 관찰한다.
  ({EncounterDetector detector, _Clock clock}) makeDetector() {
    final clock = _Clock(DateTime(2026, 1, 1));
    final detector = EncounterDetector(
      enterRadius: 15,
      exitRadius: 40,
      dwell: dwell,
      now: () => clock.value,
    );
    return (detector: detector, clock: clock);
  }

  /// 이벤트의 참가자 쌍을 "a|b" 꼴 문자열로 요약한다. 기대값 비교용.
  String pairOf(EncounterEvent event) => '${event.a.id}|${event.b.id}';

  test('진입 직후(dwell 미달) update는 이벤트 없이 pending만 유지한다', () {
    final (:detector, :clock) = makeDetector();
    final user = userAt('A', 10); // enterRadius(15) 이내.

    final events = detector.update(me, [user]);

    // 아직 dwell을 못 채웠으므로 이벤트도, 활성 사용자도 없다.
    expect(events, isEmpty);
    expect(detector.activeUserIds, isEmpty);
    // 시계는 그대로 두었다(pending만 쌓인 상태).
    expect(clock.value, DateTime(2026, 1, 1));
  });

  test('진입 후 dwell 이상 경과하면 조우 이벤트 1건이 발생한다', () {
    final (:detector, :clock) = makeDetector();
    final user = userAt('A', 10);

    // 첫 update: pending 등록.
    expect(detector.update(me, [user]), isEmpty);

    // dwell을 넘겨 시계를 전진.
    clock.advance(const Duration(seconds: 11));
    final events = detector.update(me, [user]);

    expect(events, hasLength(1));
    final event = events.single;
    // 정규화: 나(selfId)가 a에, 상대가 b에 온다.
    expect(event.a.id, EncounterDetector.selfId);
    expect(event.a.name, '나');
    expect(event.b, user);
    expect(event.involvesMe, isTrue);
    expect(event.partner, user);
    expect(event.distanceMeters, closeTo(10, 0.5));
    // 타임스탬프는 확정 시점(전진한 시계)과 일치한다.
    expect(event.timestamp, clock.value);
    // 확정되었으므로 activeUserIds에 상대가 담긴다.
    expect(detector.activeUserIds, {'A'});
  });

  test('dwell 채우기 전 exitRadius 밖으로 나가면 pending이 폐기되고 누적이 리셋된다', () {
    final (:detector, :clock) = makeDetector();

    // 진입 → pending 등록.
    expect(detector.update(me, [userAt('A', 10)]), isEmpty);

    // dwell을 못 채운 채 exitRadius(40) 밖으로 이탈 → pending 폐기.
    clock.advance(const Duration(seconds: 5));
    expect(detector.update(me, [userAt('A', 45)]), isEmpty);
    expect(detector.activeUserIds, isEmpty);

    // 다시 진입해도 이 시점부터 새로 누적한다. 폐기 직후엔 이벤트 없음.
    clock.advance(const Duration(seconds: 1));
    expect(detector.update(me, [userAt('A', 10)]), isEmpty);

    // 재진입 시각 기준으로 아직 dwell 미달(6초) → 이벤트 없음.
    clock.advance(const Duration(seconds: 6));
    expect(detector.update(me, [userAt('A', 10)]), isEmpty);
    expect(detector.activeUserIds, isEmpty);

    // 재진입 시각 기준 dwell 이상 경과 → 그제야 확정.
    clock.advance(const Duration(seconds: 5)); // 재진입 후 총 11초.
    expect(detector.update(me, [userAt('A', 10)]), hasLength(1));
    expect(detector.activeUserIds, {'A'});
  });

  test('확정된 쌍이 exitRadius 밖으로 나가면 재잠금되고, 다시 dwell을 채우면 재발생한다', () {
    final (:detector, :clock) = makeDetector();

    // 진입 후 dwell 경과 → 확정.
    expect(detector.update(me, [userAt('A', 10)]), isEmpty);
    clock.advance(const Duration(seconds: 11));
    expect(detector.update(me, [userAt('A', 10)]), hasLength(1));
    expect(detector.activeUserIds, {'A'});

    // exitRadius(40) 이상 이탈 → 재잠금(이벤트 없음, activeUserIds에서 빠짐).
    clock.advance(const Duration(seconds: 1));
    expect(detector.update(me, [userAt('A', 45)]), isEmpty);
    expect(detector.activeUserIds, isEmpty);

    // 다시 진입 → pending 재등록(즉시 확정 아님).
    clock.advance(const Duration(seconds: 1));
    expect(detector.update(me, [userAt('A', 10)]), isEmpty);

    // dwell을 다시 채우면 이벤트 재발생.
    clock.advance(const Duration(seconds: 11));
    expect(detector.update(me, [userAt('A', 10)]), hasLength(1));
    expect(detector.activeUserIds, {'A'});
  });

  test('나를 포함하지 않는 타인끼리 쌍도 dwell 게이트가 적용된다', () {
    final (:detector, :clock) = makeDetector();
    // A(100m)·B(110m)는 나와는 멀지만 서로는 10m 거리다(정북 일렬 배치).
    final users = [userAt('A', 100), userAt('B', 110)];

    // 진입 직후엔 이벤트 없음.
    expect(detector.update(me, users), isEmpty);
    expect(detector.activeUserIds, isEmpty);

    // dwell 경과 후 A|B 이벤트 1건.
    clock.advance(const Duration(seconds: 11));
    final events = detector.update(me, users);
    expect(events, hasLength(1));
    final event = events.single;
    // 나 없는 쌍은 id 정렬순으로 정규화된다.
    expect(event.a.id, 'A');
    expect(event.b.id, 'B');
    expect(event.involvesMe, isFalse);
    expect(event.distanceMeters, closeTo(10, 0.5));
    expect(detector.activeUserIds, containsAll(<String>{'A', 'B'}));
  });

  test('pending 상태에서 목록에서 사라지면 재등장 시 처음부터 누적한다', () {
    final (:detector, :clock) = makeDetector();

    // 진입 → pending. 아직 dwell 미달.
    expect(detector.update(me, [userAt('A', 10)]), isEmpty);
    clock.advance(const Duration(seconds: 5));

    // 목록에서 사라짐 → pending에서 제거.
    expect(detector.update(me, const <NearbyUser>[]), isEmpty);

    // 재등장 → pending 새로 시작. 사라지기 전 누적(5초)은 소멸.
    clock.advance(const Duration(seconds: 1));
    expect(detector.update(me, [userAt('A', 10)]), isEmpty);

    // 재등장 시각 기준 아직 dwell 미달(6초) → 이벤트 없음.
    clock.advance(const Duration(seconds: 6));
    expect(detector.update(me, [userAt('A', 10)]), isEmpty);

    // 재등장 시각 기준 dwell 이상 경과 → 확정.
    clock.advance(const Duration(seconds: 5)); // 재등장 후 총 11초.
    expect(detector.update(me, [userAt('A', 10)]), hasLength(1));
  });

  test('active 상태에서 목록에서 사라지면 재등장 시 다시 dwell을 채워야 확정된다', () {
    final (:detector, :clock) = makeDetector();

    // 진입 후 dwell 경과 → 확정.
    expect(detector.update(me, [userAt('A', 10)]), isEmpty);
    clock.advance(const Duration(seconds: 11));
    expect(detector.update(me, [userAt('A', 10)]), hasLength(1));
    expect(detector.activeUserIds, {'A'});

    // 목록에서 사라짐 → active에서 제거.
    clock.advance(const Duration(seconds: 1));
    expect(detector.update(me, const <NearbyUser>[]), isEmpty);
    expect(detector.activeUserIds, isEmpty);

    // 재등장 → pending 재시작(즉시 확정 아님).
    clock.advance(const Duration(seconds: 1));
    expect(detector.update(me, [userAt('A', 10)]), isEmpty);

    // dwell을 다시 채워야 확정.
    clock.advance(const Duration(seconds: 11));
    expect(detector.update(me, [userAt('A', 10)]), hasLength(1));
  });

  test('히스테리시스 밴드(enterRadius~exitRadius)에서도 dwell 누적이 유지된다', () {
    final (:detector, :clock) = makeDetector();

    // 진입은 enterRadius(15) 이내(10m)로 pending 시작.
    expect(detector.update(me, [userAt('A', 10)]), isEmpty);

    // 다음 update에서 20m(enterRadius 밖·exitRadius 안)로 이동해도 pending 유지.
    clock.advance(const Duration(seconds: 5));
    expect(detector.update(me, [userAt('A', 20)]), isEmpty);
    expect(detector.activeUserIds, isEmpty);

    // 밴드 안에 머문 채 dwell 이상 경과 → 20m에서도 확정된다.
    clock.advance(const Duration(seconds: 6)); // 최초 진입 후 총 11초.
    final events = detector.update(me, [userAt('A', 20)]);
    expect(events, hasLength(1));
    expect(events.single.partner.id, 'A');
    expect(events.single.distanceMeters, closeTo(20, 0.5));
    expect(detector.activeUserIds, {'A'});
  });

  test('enterRadius 밖(예: 20m)에서 처음 관찰되면 pending도 잡지 않는다', () {
    final (:detector, :clock) = makeDetector();

    // 진입 반경 밖에서 시작 → pending 등록 안 됨.
    expect(detector.update(me, [userAt('A', 20)]), isEmpty);
    expect(detector.activeUserIds, isEmpty);

    // dwell만큼 시간이 흘러도 pending이 없으므로 확정되지 않는다.
    clock.advance(const Duration(seconds: 11));
    expect(detector.update(me, [userAt('A', 20)]), isEmpty);
    expect(detector.activeUserIds, isEmpty);
  });

  test('확정된 쌍은 dwell 이후에도(enterRadius 이내) 재발생하지 않는다', () {
    final (:detector, :clock) = makeDetector();

    // 진입 후 dwell 경과 → 확정 1회.
    expect(detector.update(me, [userAt('A', 10)]), isEmpty);
    clock.advance(const Duration(seconds: 11));
    expect(detector.update(me, [userAt('A', 10)]), hasLength(1));

    // 계속 진입 반경 안이어도 재발생하지 않는다.
    clock.advance(const Duration(seconds: 11));
    expect(detector.update(me, [userAt('A', 8)]), isEmpty);
    clock.advance(const Duration(seconds: 11));
    expect(detector.update(me, [userAt('A', 5)]), isEmpty);
  });

  test('동시에 여러 쌍이 진입하면 dwell 경과 후 각 쌍마다 이벤트가 발생한다', () {
    final (:detector, :clock) = makeDetector();

    // userAt은 전부 정북 방향 일렬로 배치하므로 A(5m)·B(12m)는 서로 7m 거리다.
    // 따라서 나↔A, 나↔B에 더해 타인끼리 쌍 A↔B도 함께 성립한다.
    final users = [
      userAt('A', 5),
      userAt('B', 12),
      userAt('C', 50), // 나와도, A/B와도 진입 반경 밖 → pending 없음.
    ];

    // 진입 직후엔 이벤트 없음.
    expect(detector.update(me, users), isEmpty);

    // dwell 경과 후 세 쌍이 한꺼번에 확정된다.
    clock.advance(const Duration(seconds: 11));
    final events = detector.update(me, users);
    expect(events.map(pairOf), [
      '${EncounterDetector.selfId}|A',
      '${EncounterDetector.selfId}|B',
      'A|B',
    ]);
  });

  test('진입 후 dwell을 채우면 activeUserIds에 상대 id가 담긴다', () {
    final (:detector, :clock) = makeDetector();

    expect(detector.update(me, [userAt('A', 10)]), isEmpty);
    clock.advance(const Duration(seconds: 11));
    detector.update(me, [userAt('A', 10)]);

    expect(detector.activeUserIds, {'A'});
    // 나(selfId)는 활성 사용자 집합에 들어가지 않는다.
    expect(detector.activeUserIds, isNot(contains(EncounterDetector.selfId)));
  });

  test('확정 후 exitRadius 이상 이탈하면 activeUserIds에서 제거된다', () {
    final (:detector, :clock) = makeDetector();

    expect(detector.update(me, [userAt('A', 10)]), isEmpty);
    clock.advance(const Duration(seconds: 11));
    detector.update(me, [userAt('A', 10)]);
    expect(detector.activeUserIds, {'A'});

    // exitRadius(40m) 이상 이탈 → 활성 집합에서 빠진다.
    clock.advance(const Duration(seconds: 1));
    detector.update(me, [userAt('A', 45)]);
    expect(detector.activeUserIds, isEmpty);
  });

  test('확정 후 목록에서 사라지면 activeUserIds에서 제거된다', () {
    final (:detector, :clock) = makeDetector();

    expect(detector.update(me, [userAt('A', 10)]), isEmpty);
    clock.advance(const Duration(seconds: 11));
    detector.update(me, [userAt('A', 10)]);
    expect(detector.activeUserIds, {'A'});

    // A가 목록에서 사라짐 → 활성 집합에서 빠진다.
    clock.advance(const Duration(seconds: 1));
    detector.update(me, const <NearbyUser>[]);
    expect(detector.activeUserIds, isEmpty);
  });

  test('타인끼리 조우도 dwell 경과 후 activeUserIds에 두 id가 모두 담긴다', () {
    final (:detector, :clock) = makeDetector();

    // A(100m)·B(110m)는 나와는 멀지만 서로는 10m라 A↔B 쌍이 성립한다.
    final users = [userAt('A', 100), userAt('B', 110)];
    expect(detector.update(me, users), isEmpty);

    clock.advance(const Duration(seconds: 11));
    detector.update(me, users);

    expect(detector.activeUserIds, containsAll(<String>{'A', 'B'}));
  });

  test('enterRadius >= exitRadius이면 생성 시 assert로 막는다', () {
    expect(
      () => EncounterDetector(enterRadius: 40, exitRadius: 15),
      throwsA(isA<AssertionError>()),
    );
  });
}

/// 테스트에서 update 사이에 시각을 전진시키기 위한 가변 시계.
///
/// EncounterDetector에 `now: () => clock.value`로 주입하고, update 호출
/// 사이에 [advance]로 시각을 밀어 dwell 경과를 결정적으로 재현한다.
class _Clock {
  _Clock(this.value);

  DateTime value;

  void advance(Duration delta) => value = value.add(delta);
}
