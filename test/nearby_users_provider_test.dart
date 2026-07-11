import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:gps_meeting_app/features/map/providers/location_provider.dart';
import 'package:gps_meeting_app/features/map/providers/nearby_users_provider.dart';
import 'package:gps_meeting_app/features/map/providers/user_profiles_provider.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/location_test_helpers.dart';

const _distance = Distance();
const _me = LatLng(37.5, 127.0);

/// [loadProfiles]가 주어진 future로 resolve될 때까지 지연되는 repository.
class _DelayedRepo extends UserProfileRepository {
  _DelayedRepo(this._future);

  final Future<List<NearbyUser>> _future;

  @override
  Future<List<NearbyUser>> loadProfiles() => _future;
}

void main() {
  group('computeEncounters — 내 위치 기준', () {
    test('임계값(30m) 이내면 조우로 판정한다(경계 포함)', () {
      // 정확히 30m 지점 → <= 30 이므로 조우.
      final user = fakeSimUser('user1', position: _distance.offset(_me, 30, 0));

      final result = computeEncounters(
        myPosition: _me,
        users: [user],
        already: const {},
      );

      expect(result, contains('user1'));
    });

    test('임계값을 벗어나면(32m) 조우하지 않는다', () {
      final user = fakeSimUser('user1', position: _distance.offset(_me, 32, 0));

      final result = computeEncounters(
        myPosition: _me,
        users: [user],
        already: const {},
      );

      expect(result, isNot(contains('user1')));
    });
  });

  group('computeEncounters — 다른 시뮬레이션 사용자 기준', () {
    test('내게서는 멀어도 서로 30m 이내면 둘 다 조우한다', () {
      // 둘 다 나에게서 200m 떨어뜨리되, 서로는 20m 이내로 배치.
      final far = _distance.offset(_me, 200, 90);
      final a = fakeSimUser('userA', position: far);
      final b = fakeSimUser('userB', position: _distance.offset(far, 20, 0));

      final result = computeEncounters(
        myPosition: _me,
        users: [a, b],
        already: const {},
      );

      expect(result, containsAll(['userA', 'userB']));
    });

    test('서로도 멀고 나에게서도 멀면 아무도 조우하지 않는다', () {
      final a = fakeSimUser('userA', position: _distance.offset(_me, 200, 0));
      final b = fakeSimUser('userB', position: _distance.offset(_me, 200, 180));

      final result = computeEncounters(
        myPosition: _me,
        users: [a, b],
        already: const {},
      );

      expect(result, isEmpty);
    });
  });

  test('한 번 조우하면 멀어져도 유지된다(sticky)', () {
    // 지금은 멀리 있지만 이미 조우 집합에 포함된 사용자.
    final user = fakeSimUser('user1', position: _distance.offset(_me, 500, 0));

    final result = computeEncounters(
      myPosition: _me,
      users: [user],
      already: const {'user1'},
    );

    expect(result, contains('user1'));
  });

  group('randomPointNear', () {
    test('생성된 지점은 항상 지정 반경 이내다', () {
      final random = Random(42);
      for (var i = 0; i < 50; i++) {
        final point = randomPointNear(_me, 200, random);
        expect(_distance.as(LengthUnit.Meter, _me, point), lessThanOrEqualTo(200));
      }
    });
  });

  group('randomWalkStep', () {
    test('활동 반경(300m)을 벗어나면 중심 쪽으로 되돌아온다', () {
      final random = Random(7);
      // 400m 밖에서 시작 → 한 스텝 뒤 중심과의 거리가 줄어야 한다.
      final start = _distance.offset(_me, 400, 0);
      final startDist = _distance.as(LengthUnit.Meter, _me, start);
      final next = randomWalkStep(start, _me, random);
      final nextDist = _distance.as(LengthUnit.Meter, _me, next);

      expect(nextDist, lessThan(startDist));
    });
  });

  test('프로필 로딩 중에는 스폰하지 않고, 로드 완료 후 한 번만 스폰한다', () async {
    // 프로필 로드를 임의로 지연시킨다.
    final completer = Completer<List<NearbyUser>>();
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(
          FakeLocationService(Stream.value(fakePosition(37.5, 127.0))),
        ),
        // 실제 Firebase에 닿지 않도록 초기화를 no-op으로 대체한다.
        firebaseInitProvider.overrideWith((ref) async {}),
        userProfileRepositoryProvider
            .overrideWithValue(_DelayedRepo(completer.future)),
      ],
    );
    addTearDown(container.dispose);

    // provider들을 살려두고 스트림/future가 전달되도록 구독한다.
    container.listen(positionStreamProvider, (_, __) {});
    container.listen(nearbyUsersProvider, (_, __) {});
    await _settle();

    // 내 위치는 도착했지만 프로필은 아직 로딩 중 → 스폰하지 않는다.
    // (과거엔 defaultNearbyUsers로 즉시 스폰돼 이후 재빌드 시 텔레포트했다.)
    expect(container.read(nearbyUsersProvider), isEmpty);

    // 프로필 로드 완료 → 이때 비로소 한 번 스폰된다.
    completer.complete(defaultNearbyUsers);
    await _settle();

    expect(container.read(nearbyUsersProvider), hasLength(5));
  });
}

/// 이벤트 큐(마이크로태스크 + zero-delay 타이머)를 충분히 비운다.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
