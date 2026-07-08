import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:gps_meeting_app/features/map/services/encounter_detector.dart';

import 'helpers/location_test_helpers.dart';

void main() {
  // 좌표 생성과 조우 판정의 기준점. userAt의 기본 중심과 동일하다.
  final me = testCenter;

  /// 타임스탬프를 결정적으로 만드는 detector. now는 고정 시각을 반환한다.
  EncounterDetector makeDetector({DateTime? fixedNow}) => EncounterDetector(
        now: () => fixedNow ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  test('enterRadius 이내로 진입하면 이벤트가 1회 발생한다', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1000);
    final detector = makeDetector(fixedNow: now);
    final user = userAt('A', 10); // 15m 이내.

    final events = detector.update(me, [user]);

    expect(events, hasLength(1));
    final event = events.single;
    expect(event.user, user);
    expect(event.distanceMeters, closeTo(10, 0.5));
    expect(event.timestamp, now);
  });

  test('enterRadius 밖(예: 20m)이면 이벤트가 발생하지 않는다', () {
    final detector = makeDetector();
    final events = detector.update(me, [userAt('A', 20)]);
    expect(events, isEmpty);
  });

  test('이미 조우 중이면 enterRadius 이내라도 재발생하지 않는다', () {
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

  test('동시에 여러 명이 진입하면 각각 이벤트가 발생한다', () {
    final detector = makeDetector();

    final events = detector.update(me, [
      userAt('A', 5),
      userAt('B', 12),
      userAt('C', 50), // 범위 밖 → 이벤트 없음.
    ]);

    expect(events.map((e) => e.user.id), ['A', 'B']);
  });

  test('enterRadius >= exitRadius이면 생성 시 assert로 막는다', () {
    expect(
      () => EncounterDetector(enterRadius: 40, exitRadius: 15),
      throwsA(isA<AssertionError>()),
    );
  });
}
