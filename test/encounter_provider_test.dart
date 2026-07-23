import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gps_meeting_app/features/map/models/encounter_event.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:gps_meeting_app/features/map/providers/encounter_provider.dart';
import 'package:gps_meeting_app/features/map/providers/location_provider.dart';
import 'package:gps_meeting_app/features/map/providers/nearby_users_provider.dart';
import 'package:gps_meeting_app/features/map/services/encounter_detector.dart';

import 'helpers/location_test_helpers.dart';

void main() {
  final center = testCenter;

  /// 이벤트 루프를 여러 턴 진행시켜 스트림 방출이 전파되도록 한다.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// 주입한 위치/근처 사용자 스트림으로 구성한 컨테이너와, encounterEventsProvider가
  /// 방출한 이벤트를 모으는 리스트들을 함께 만든다.
  ///
  /// [batches]는 방출된 배치(한 재계산 단위)를 그대로 모으고, [events]는 그
  /// 배치들을 펼쳐 담아 전체 이벤트 수를 편하게 검증하게 한다.
  ({
    ProviderContainer container,
    List<EncounterEvent> events,
    List<List<EncounterEvent>> batches,
  }) setUpContainer(
    Stream<Position> positionStream,
    Stream<List<NearbyUser>> nearbyStream,
  ) {
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider
            .overrideWithValue(FakeLocationService(positionStream)),
        nearbyUsersServiceProvider.overrideWithValue(
          ControlledNearbyUsersService(nearbyStream),
        ),
        // dwell을 0으로 줄여, 벽시계 10초를 전진시키지 않고도 조우 확정을
        // 결정적으로 재현한다. dwell=0이면 진입한 그 방출에서 pending 등록만
        // 되고, 확정은 다음 방출에서 일어난다(2스텝). 반경은 provider 기본값과
        // 동일하게 명시한다(enter=60/exit=100).
        encounterDetectorProvider.overrideWith(
          (ref) => EncounterDetector(
            enterRadius: 60,
            exitRadius: 100,
            dwell: Duration.zero,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final events = <EncounterEvent>[];
    final batches = <List<EncounterEvent>>[];
    container.listen(
      encounterEventsProvider,
      (previous, next) {
        final batch = next.value;
        if (batch != null) {
          batches.add(batch);
          events.addAll(batch);
        }
      },
      // StreamProvider 첫 상태(로딩)에는 value가 없으므로 즉시 발화해도 안전하다.
      fireImmediately: true,
    );
    return (container: container, events: events, batches: batches);
  }

  test('사용자가 진입 반경 이내로 이동하면 나↔상대 조우 이벤트를 방출한다', () async {
    final positions = StreamController<Position>();
    addTearDown(positions.close);
    final nearby = StreamController<List<NearbyUser>>();
    addTearDown(nearby.close);

    final ctx = setUpContainer(positions.stream, nearby.stream);

    // 내 위치가 먼저 도착해야 근처 사용자 스트림 구독이 시작된다.
    positions.add(fakePosition(center.latitude, center.longitude));
    await settle();

    // 처음엔 멀리(100m) 있어 조우가 아니다.
    nearby.add([userAt('A', 100)]);
    await settle();
    expect(ctx.events, isEmpty);

    // 진입 반경 이내(10m)로 이동 → pending 등록만 된다(dwell=0에서도 확정은
    // 다음 방출에서).
    nearby.add([userAt('A', 10)]);
    await settle();
    expect(ctx.events, isEmpty);

    // 같은 위치를 한 번 더 방출하면 pending이 dwell(0)을 충족해 확정된다.
    nearby.add([userAt('A', 10)]);
    await settle();

    expect(ctx.events, hasLength(1));
    final event = ctx.events.single;
    expect(event.involvesMe, isTrue);
    expect(event.partner.id, 'A');
    expect(event.distanceMeters, closeTo(10, 0.5));
  });

  test('한 번의 방출에서 여러 쌍이 진입하면 나↔상대·타인끼리 이벤트가 배치 1개로 묶인다',
      () async {
    final positions = StreamController<Position>();
    addTearDown(positions.close);
    final nearby = StreamController<List<NearbyUser>>();
    addTearDown(nearby.close);

    final ctx = setUpContainer(positions.stream, nearby.stream);

    positions.add(fakePosition(center.latitude, center.longitude));
    await settle();

    // A(10m)·B(12m)를 배치한다. userAt은 정북 일렬 배치라 A↔B도 서로 2m 거리로
    // 진입하므로 3쌍이 성립하지만, dwell=0에서도 이 첫 방출은 세 쌍을 pending에
    // 등록만 한다. 확정은 다음 방출에서 일어난다.
    nearby.add([userAt('A', 10), userAt('B', 12)]);
    await settle();
    expect(ctx.batches, isEmpty);

    // 같은 배치를 한 번 더 방출하면 세 pending이 dwell(0)을 충족해 한 배치로
    // 확정된다.
    nearby.add([userAt('A', 10), userAt('B', 12)]);
    await settle();

    // 한 재계산에서 나온 이벤트 전부가 하나의 배치로 묶여 방출되어야 하고,
    // 그 배치에는 나↔사용자 이벤트와 타인끼리 이벤트가 함께 담긴다.
    expect(ctx.batches, hasLength(1));
    final batch = ctx.batches.single;
    expect(batch, hasLength(3));
    expect(
      batch.map((e) => '${e.a.id}|${e.b.id}'),
      containsAll([
        '${EncounterDetector.selfId}|A',
        '${EncounterDetector.selfId}|B',
        'A|B',
      ]),
    );
    expect(batch.where((e) => e.involvesMe), hasLength(2));
    expect(batch.where((e) => !e.involvesMe), hasLength(1));
  });

  test('사용자 목록이 로딩 중인 동안에는 위치가 있어도 이벤트가 없다', () async {
    final positions = StreamController<Position>();
    addTearDown(positions.close);
    // 근처 사용자 스트림은 아무것도 방출하지 않아 계속 로딩 상태로 둔다.
    final nearby = StreamController<List<NearbyUser>>();
    addTearDown(nearby.close);

    final ctx = setUpContainer(positions.stream, nearby.stream);

    positions.add(fakePosition(center.latitude, center.longitude));
    await settle();

    expect(ctx.events, isEmpty);
  });

  test('멀어지면 unlockedUsersProvider에서 해당 id가 재잠금된다', () async {
    final positions = StreamController<Position>();
    addTearDown(positions.close);
    final nearby = StreamController<List<NearbyUser>>();
    addTearDown(nearby.close);

    final ctx = setUpContainer(positions.stream, nearby.stream);
    // autoDispose 연쇄를 살리기 위해 해금 provider를 구독해 둔다. 이 구독만으로
    // encounterUpdatesProvider 체인도 함께 유지되어야 정상이다.
    ctx.container.listen(
      unlockedUsersProvider,
      (_, __) {},
      fireImmediately: true,
    );

    positions.add(fakePosition(center.latitude, center.longitude));
    await settle();

    // detector는 override로 enter=60/exit=100/dwell=0을 쓴다.
    // 진입: 10m는 enter(60) 미만 → pending 등록만 된다(아직 해금 아님).
    nearby.add([userAt('A', 10)]);
    await settle();
    expect(ctx.container.read(unlockedUsersProvider), isNot(contains('A')));

    // 같은 위치를 한 번 더 방출하면 dwell(0)을 충족해 active가 되어 해금된다.
    nearby.add([userAt('A', 10)]);
    await settle();
    expect(ctx.container.read(unlockedUsersProvider), contains('A'));

    // 이탈: 200m는 exit(100) 초과 → 활성 집합에서 빠져 재잠금된다.
    nearby.add([userAt('A', 200)]);
    await settle();
    expect(ctx.container.read(unlockedUsersProvider), isNot(contains('A')));
  });

  test('사용자 목록이 오류인 동안에는 낡은 데이터로 조우를 만들지 않는다', () async {
    final positions = StreamController<Position>();
    addTearDown(positions.close);
    final nearby = StreamController<List<NearbyUser>>();
    addTearDown(nearby.close);

    final ctx = setUpContainer(positions.stream, nearby.stream);

    positions.add(fakePosition(center.latitude, center.longitude));
    await settle();

    // 근처 사용자 스트림이 오류를 방출 → unwrapPrevious().value가 null이므로
    // detector가 돌지 않아야 한다.
    nearby.addError(StateError('nearby down'));
    await settle();

    expect(ctx.events, isEmpty);
  });
}
