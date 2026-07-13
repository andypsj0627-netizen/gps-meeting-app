import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/map/models/encounter_event.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:gps_meeting_app/features/map/services/encounter_detector.dart';

import 'helpers/location_test_helpers.dart';

void main() {
  // 좌표 생성과 조우 판정의 기준점. userAt의 기본 중심과 동일하다.
  final me = testCenter;

  /// 타임스탬프를 결정적으로 만드는 detector. now는 고정 시각을 반환한다.
  ///
  /// 반경은 명시적으로 15/40을 주입한다. AppConstants의 값은 테스트 단계에서
  /// 관찰 편의를 위해 조정될 수 있으므로, 단위 테스트는 기본값에 의존하지 않는다.
  EncounterDetector makeDetector({DateTime? fixedNow}) => EncounterDetector(
        enterRadius: 15,
        exitRadius: 40,
        now: () => fixedNow ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// 이벤트의 참가자 쌍을 "a|b" 꼴 문자열로 요약한다. 기대값 비교용.
  String pairOf(EncounterEvent event) => '${event.a.id}|${event.b.id}';

  test('enterRadius 이내로 진입하면 나↔상대 이벤트가 1회 발생한다', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1000);
    final detector = makeDetector(fixedNow: now);
    final user = userAt('A', 10); // 15m 이내.

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
    expect(event.timestamp, now);
  });

  test('enterRadius 밖(예: 20m)이면 이벤트가 발생하지 않는다', () {
    final detector = makeDetector();
    final events = detector.update(me, [userAt('A', 20)]);
    expect(events, isEmpty);
  });

  test('이미 조우 중인 쌍은 enterRadius 이내라도 재발생하지 않는다', () {
    final detector = makeDetector();

    // 첫 진입 → 이벤트 1회.
    expect(detector.update(me, [userAt('A', 10)]), hasLength(1));
    // 여전히 진입 반경 안 → 재발생 없음.
    expect(detector.update(me, [userAt('A', 8)]), isEmpty);
    expect(detector.update(me, [userAt('A', 5)]), isEmpty);
  });

  test('exitRadius 미만(20~39m)으로 벗어나도 상태를 유지해 재진입해도 이벤트가 없다', () {
    final detector = makeDetector();

    expect(detector.update(me, [userAt('A', 10)]), hasLength(1));
    // 20~39m: enterRadius 밖이지만 exitRadius(40m) 미만 → 여전히 조우 상태.
    expect(detector.update(me, [userAt('A', 25)]), isEmpty);
    expect(detector.update(me, [userAt('A', 35)]), isEmpty);
    // 다시 진입 반경 안으로 들어와도, 상태가 유지되므로 재발생하지 않는다.
    expect(detector.update(me, [userAt('A', 10)]), isEmpty);
  });

  test('exitRadius 이상 이탈 후 재진입하면 이벤트가 재발생한다', () {
    final detector = makeDetector();

    expect(detector.update(me, [userAt('A', 10)]), hasLength(1));
    // exitRadius(40m) 이상 이탈 → 상태 해제(이벤트 없음).
    expect(detector.update(me, [userAt('A', 45)]), isEmpty);
    // 다시 진입 반경 안 → 이벤트 재발생.
    expect(detector.update(me, [userAt('A', 10)]), hasLength(1));
  });

  test('목록에서 사라졌다 다시 나타나 enterRadius 이내면 이벤트가 발생한다', () {
    final detector = makeDetector();

    expect(detector.update(me, [userAt('A', 10)]), hasLength(1));
    // A가 목록에서 사라짐 → 상태 초기화(이벤트 없음).
    expect(detector.update(me, const <NearbyUser>[]), isEmpty);
    // 다시 나타나 진입 반경 안 → 새 이벤트.
    expect(detector.update(me, [userAt('A', 10)]), hasLength(1));
  });

  test('동시에 여러 쌍이 진입하면 각 쌍마다 이벤트가 발생한다', () {
    final detector = makeDetector();

    // userAt은 전부 정북 방향 일렬로 배치하므로 A(5m)·B(12m)는 서로 7m 거리다.
    // 따라서 나↔A, 나↔B에 더해 타인끼리 쌍 A↔B도 함께 성립한다.
    final events = detector.update(me, [
      userAt('A', 5),
      userAt('B', 12),
      userAt('C', 50), // 나와도, A/B와도 진입 반경 밖 → 이벤트 없음.
    ]);

    expect(events.map(pairOf), [
      '${EncounterDetector.selfId}|A',
      '${EncounterDetector.selfId}|B',
      'A|B',
    ]);
  });

  test('나와 멀어도 타인끼리 enterRadius 이내면 쌍 이벤트가 발생한다', () {
    final detector = makeDetector();

    // A(100m)·B(110m)는 나와는 멀지만 서로는 10m 거리다(정북 일렬 배치).
    final events = detector.update(me, [userAt('A', 100), userAt('B', 110)]);

    expect(events, hasLength(1));
    final event = events.single;
    // 나 없는 쌍은 id 정렬순으로 정규화된다.
    expect(event.a.id, 'A');
    expect(event.b.id, 'B');
    expect(event.involvesMe, isFalse);
    expect(event.distanceMeters, closeTo(10, 0.5));
  });

  test('타인끼리 쌍도 exitRadius 미만으로 유지되는 동안 재발생하지 않는다', () {
    final detector = makeDetector();

    // A↔B 10m → 쌍 이벤트 1회. (나와는 계속 100m 이상이라 무관하다.)
    expect(
      detector.update(me, [userAt('A', 100), userAt('B', 110)]),
      hasLength(1),
    );
    // A↔B 30m: enterRadius 밖이지만 exitRadius(40m) 미만 → 상태 유지.
    expect(
      detector.update(me, [userAt('A', 100), userAt('B', 130)]),
      isEmpty,
    );
    // 다시 진입 반경 안(8m)으로 돌아와도 재발생하지 않는다.
    expect(
      detector.update(me, [userAt('A', 100), userAt('B', 108)]),
      isEmpty,
    );
    // A↔B 45m: exitRadius 이상 → 상태 해제(이벤트 없음).
    expect(
      detector.update(me, [userAt('A', 100), userAt('B', 145)]),
      isEmpty,
    );
    // 다시 진입 반경 안 → 쌍 이벤트 재발생.
    expect(
      detector.update(me, [userAt('A', 100), userAt('B', 110)]),
      hasLength(1),
    );
  });

  test('한쪽이 목록에서 사라지면 쌍 상태가 해제되어 재등장 시 이벤트가 재발생한다', () {
    final detector = makeDetector();

    expect(
      detector.update(me, [userAt('A', 100), userAt('B', 110)]),
      hasLength(1),
    );
    // B가 목록에서 사라짐 → A|B 쌍 상태 초기화(이벤트 없음).
    expect(detector.update(me, [userAt('A', 100)]), isEmpty);
    // B가 같은 자리로 재등장해 진입 반경 안 → 새 쌍 이벤트.
    expect(
      detector.update(me, [userAt('A', 100), userAt('B', 110)]),
      hasLength(1),
    );
  });

  test('진입하면 activeUserIds에 상대 id가 담긴다', () {
    final detector = makeDetector();

    detector.update(me, [userAt('A', 10)]);

    expect(detector.activeUserIds, {'A'});
    // 나(selfId)는 활성 사용자 집합에 들어가지 않는다.
    expect(detector.activeUserIds, isNot(contains(EncounterDetector.selfId)));
  });

  test('exitRadius 이상 이탈하면 activeUserIds에서 제거된다', () {
    final detector = makeDetector();

    detector.update(me, [userAt('A', 10)]);
    expect(detector.activeUserIds, {'A'});

    // exitRadius(40m) 이상 이탈 → 활성 집합에서 빠진다.
    detector.update(me, [userAt('A', 45)]);
    expect(detector.activeUserIds, isEmpty);
  });

  test('목록에서 사라지면 activeUserIds에서 제거된다', () {
    final detector = makeDetector();

    detector.update(me, [userAt('A', 10)]);
    expect(detector.activeUserIds, {'A'});

    // A가 목록에서 사라짐 → 활성 집합에서 빠진다.
    detector.update(me, const <NearbyUser>[]);
    expect(detector.activeUserIds, isEmpty);
  });

  test('타인끼리 조우도 activeUserIds에 두 id가 모두 담긴다', () {
    final detector = makeDetector();

    // A(100m)·B(110m)는 나와는 멀지만 서로는 10m라 A↔B 쌍이 활성이다.
    detector.update(me, [userAt('A', 100), userAt('B', 110)]);

    expect(detector.activeUserIds, containsAll(<String>{'A', 'B'}));
  });

  test('enterRadius >= exitRadius이면 생성 시 assert로 막는다', () {
    expect(
      () => EncounterDetector(enterRadius: 40, exitRadius: 15),
      throwsA(isA<AssertionError>()),
    );
  });
}
