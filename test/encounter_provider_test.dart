import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gps_meeting_app/features/map/models/encounter_event.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:gps_meeting_app/features/map/providers/encounter_provider.dart';
import 'package:gps_meeting_app/features/map/providers/location_provider.dart';
import 'package:gps_meeting_app/features/map/providers/nearby_users_provider.dart';

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

  test('사용자가 15m 이내로 이동하면 조우 이벤트를 방출한다', () async {
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

    // 15m 이내로 이동 → 조우 이벤트 방출.
    nearby.add([userAt('A', 10)]);
    await settle();

    expect(ctx.events, hasLength(1));
    expect(ctx.events.single.user.id, 'A');
    expect(ctx.events.single.distanceMeters, closeTo(10, 0.5));
  });

  test('한 번의 방출에서 2명이 동시에 진입하면 배치 1개(길이 2)로 방출된다', () async {
    final positions = StreamController<Position>();
    addTearDown(positions.close);
    final nearby = StreamController<List<NearbyUser>>();
    addTearDown(nearby.close);

    final ctx = setUpContainer(positions.stream, nearby.stream);

    positions.add(fakePosition(center.latitude, center.longitude));
    await settle();

    // 같은 방출에 두 사용자를 모두 진입 반경(15m) 안에 배치한다.
    nearby.add([userAt('A', 10), userAt('B', 12)]);
    await settle();

    // 한 재계산에서 나온 두 이벤트가 하나의 배치로 묶여 방출되어야 한다.
    expect(ctx.batches, hasLength(1));
    expect(ctx.batches.single, hasLength(2));
    expect(
      ctx.batches.single.map((e) => e.user.id),
      containsAll(['A', 'B']),
    );
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
