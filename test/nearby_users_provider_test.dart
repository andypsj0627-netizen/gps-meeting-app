import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:gps_meeting_app/features/map/providers/nearby_users_provider.dart';
import 'package:gps_meeting_app/features/map/providers/user_profiles_provider.dart';
import 'package:gps_meeting_app/features/map/services/route_planner.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/location_test_helpers.dart';

/// 시뮬레이션에 넣을 인물 명단. 실제 앱과 동일하게 Firestore 기본 프로필 5명을 쓴다.
const _roster = defaultNearbyUsers;

/// 호출을 기록하고 주입한 빌더로 경로를 만드는 fake 플래너.
///
/// 빌더가 없으면 직선 경로 [from, to]를 반환한다. 네트워크를 전혀 사용하지
/// 않으므로 테스트가 결정적으로 동작한다.
class _FakeRoutePlanner implements RoutePlanner {
  _FakeRoutePlanner([this._builder]);

  final List<LatLng> Function(LatLng from, LatLng to)? _builder;

  /// true면 결과를 직선 폴백([RouteResult.isFallback])으로 표시한다.
  bool isFallback = false;

  /// [planRoute] 호출 횟수. "도착 후 새 경로 요청" 검증에 사용한다.
  int callCount = 0;

  /// 요청된 (출발지, 목적지) 쌍 기록. 목적지 선정 규칙 검증에 사용한다.
  final List<({LatLng from, LatLng to})> requests = [];

  @override
  Future<RouteResult> planRoute(LatLng from, LatLng to) async {
    callCount++;
    requests.add((from: from, to: to));
    return RouteResult(
      points: _builder?.call(from, to) ?? [from, to],
      isFallback: isFallback,
    );
  }
}

/// 기본 틱 주기(300ms). 테스트는 fake_async로 시간을 진행시키므로 실시간
/// 대기는 발생하지 않는다.
const _tick = Duration(milliseconds: 300);

/// 틱당 기대 이동거리 계산용 틱 시간(초).
const double _tickSeconds = 0.3;

void main() {
  // 서브미터 이동을 검증하므로 미터 반올림을 끈 공용 거리 계산기를 사용한다.
  const distance = testDistance;
  const center = testCenter;

  /// fake_async 안에서 서비스를 구독하고 [elapse]만큼 시간을 진행시킨 뒤,
  /// 그동안 수신한 스냅샷 목록을 반환한다.
  List<List<NearbyUser>> collect(
    FakeAsync async,
    FakeNearbyUsersService service,
    Duration elapse,
  ) {
    final emissions = <List<NearbyUser>>[];
    final sub = service.watchNearbyUsers(center, _roster).listen(emissions.add);
    // 초기 방출(마이크로태스크)을 먼저 전달받은 뒤 시간을 진행시킨다.
    async.flushMicrotasks();
    async.elapse(elapse);
    sub.cancel();
    async.flushMicrotasks();
    return emissions;
  }

  group('FakeNearbyUsersService', () {
    test('첫 방출은 roster 5명이며 모두 center 100~300m 반경에 있다', () {
      fakeAsync((async) {
        final service = FakeNearbyUsersService(
          random: Random(42),
          tickInterval: _tick,
          routePlanner: _FakeRoutePlanner(),
        );

        final emissions = collect(async, service, Duration.zero);

        expect(emissions, isNotEmpty);
        final first = emissions.first;
        expect(first.length, 5);
        expect(
          first.map((u) => u.name).toList(),
          _roster.map((u) => u.name).toList(),
        );
        // 프로필의 나이/성별이 시뮬레이션 방출에도 보존된다.
        expect(first.first.age, _roster.first.age);
        expect(first.first.gender, _roster.first.gender);
        for (final user in first) {
          final d = distance.distance(center, user.position);
          expect(d, greaterThanOrEqualTo(100 - 0.5));
          expect(d, lessThanOrEqualTo(300 + 0.5));
        }
      });
    });

    test('보행 중에는 틱마다 정확히 속도×틱시간 만큼 이동한다', () {
      fakeAsync((async) {
        // 속도를 1.2m/s로 고정 → 틱(0.3s)당 0.36m 이동해야 한다.
        const speed = 1.2;
        final service = FakeNearbyUsersService(
          random: Random(42),
          tickInterval: _tick,
          routePlanner: _FakeRoutePlanner(),
          minSpeed: speed,
          maxSpeed: speed,
        );

        // 초기 배치 + 5틱 = 6개 스냅샷. 경로 요청은 구독 직후 시작되어
        // 첫 틱 전에 완료되므로(마이크로태스크) 1틱째부터 보행한다.
        final emissions = collect(async, service, _tick * 5);
        expect(emissions.length, 6);

        for (var i = 1; i < emissions.length; i++) {
          final prev = emissions[i - 1];
          final curr = emissions[i];
          for (var j = 0; j < prev.length; j++) {
            expect(prev[j].id, curr[j].id); // 같은 사용자끼리 비교(순서 보존).
            final moved =
                distance.distance(prev[j].position, curr[j].position);
            expect(moved, closeTo(speed * _tickSeconds, 0.1));
          }
        }
      });
    });

    test('폴리라인 세그먼트 경계를 넘어가면 다음 세그먼트로 이월하여 보간한다', () {
      fakeAsync((async) {
        const speed = 1.2; // 틱당 0.36m.
        // 경로: from → 북쪽 0.2m(p1) → p1에서 동쪽 30m.
        // 첫 틱에 0.2m 세그먼트를 소진하고 남은 0.16m를 다음 세그먼트에서 걷는다.
        final service = FakeNearbyUsersService(
          random: Random(42),
          tickInterval: _tick,
          routePlanner: _FakeRoutePlanner((from, to) {
            final p1 = distance.offset(from, 0.2, 0);
            return [from, p1, distance.offset(p1, 30, 90)];
          }),
          minSpeed: speed,
          maxSpeed: speed,
        );

        final emissions = collect(async, service, _tick);
        expect(emissions.length, 2);

        // 첫 사용자로 검증: 초기 위치 기준 굽은 경로를 따라 걸었는지 확인.
        final start = emissions[0][0].position;
        final afterTick = emissions[1][0].position;
        final p1 = distance.offset(start, 0.2, 0);

        // 굽이(p1)에서 0.16m 지점에 있어야 한다 (0.36 - 0.2 = 0.16).
        expect(distance.distance(p1, afterTick), closeTo(0.16, 0.02));
        // 직선 이동이었다면 시작점에서 0.36m지만, 굽은 경로라 더 가깝다.
        // sqrt(0.2^2 + 0.16^2) ≈ 0.256m.
        expect(distance.distance(start, afterTick), closeTo(0.256, 0.02));
      });
    });

    test('도착 후 1~3초 대기하고 새 경로를 요청한다', () {
      fakeAsync((async) {
        const speed = 1.2; // 틱당 0.36m.
        // 1m짜리 짧은 경로 → 3틱째에 도착한다.
        final planner = _FakeRoutePlanner(
          (from, to) => [from, distance.offset(from, 1, 0)],
        );
        final service = FakeNearbyUsersService(
          random: Random(42),
          tickInterval: _tick,
          routePlanner: planner,
          minSpeed: speed,
          maxSpeed: speed,
        );

        final sub =
            service.watchNearbyUsers(center, _roster).listen((_) {});

        // 구독 직후: 5명 각각 최초 경로 요청.
        async.flushMicrotasks();
        expect(planner.callCount, 5);

        // 도착(3틱 ≈ 0.9s) 전까지는 새 요청이 없다.
        async.elapse(_tick * 3);
        expect(planner.callCount, 5);

        // 최대 대기(3s)까지 진행하면 전원(5명)이 새 경로를 요청했어야 한다.
        // (그 사이 두 번째 도착/재요청 사이클이 시작됐을 수 있어 하한으로 검증.)
        async.elapse(const Duration(seconds: 3) + _tick);
        expect(planner.callCount, greaterThanOrEqualTo(10));

        sub.cancel();
        async.flushMicrotasks();
      });
    });

    test('직선 폴백 경로로 도착하면 10~20초 백오프 후에 새 경로를 요청한다', () {
      fakeAsync((async) {
        const speed = 1.2; // 틱당 0.36m.
        // 항상 폴백으로 표시되는 1m짜리 경로 → 3틱째(≈0.9s)에 도착한다.
        final planner = _FakeRoutePlanner(
          (from, to) => [from, distance.offset(from, 1, 0)],
        )..isFallback = true;
        final service = FakeNearbyUsersService(
          random: Random(42),
          tickInterval: _tick,
          routePlanner: planner,
          minSpeed: speed,
          maxSpeed: speed,
        );

        final sub =
            service.watchNearbyUsers(center, _roster).listen((_) {});
        async.flushMicrotasks();
        expect(planner.callCount, 5);

        // 최소 백오프(10s)가 끝나기 전(도착 0.9s + 10s = 10.9s)에는
        // 재요청이 없어야 한다 — 1~3초 대기였다면 이미 여러 번 재요청했을 시간.
        async.elapse(const Duration(seconds: 10));
        expect(planner.callCount, 5);

        // 최대 백오프(20s)를 지나면 전원이 새 경로를 요청했어야 한다.
        async.elapse(const Duration(seconds: 12));
        expect(planner.callCount, greaterThanOrEqualTo(10));

        sub.cancel();
        async.flushMicrotasks();
      });
    });

    test('목적지는 항상 center 500m 반경 내, 현 위치 기준 50~300m에서 뽑힌다', () {
      // 주의: 500m 경계는 "목적지 선정 시" 보장이다. 실제 도로 경로(플래너 결과)는
      // 두 지점을 잇기 위해 경계를 다소 벗어날 수 있으므로, 여기서는 서비스가
      // 플래너에 넘기는 목적지 자체의 불변식을 검증한다.
      fakeAsync((async) {
        // 1m짜리 짧은 경로로 도착/재출발 사이클을 빠르게 반복시킨다.
        final planner = _FakeRoutePlanner(
          (from, to) => [from, distance.offset(from, 1, 0)],
        );
        final service = FakeNearbyUsersService(
          random: Random(99),
          tickInterval: _tick,
          routePlanner: planner,
          minSpeed: 1.2,
          maxSpeed: 1.2,
        );

        final sub =
            service.watchNearbyUsers(center, _roster).listen((_) {});
        // 시뮬레이션 60초 → 걷기/대기/재출발이 수십 번 반복된다.
        async.elapse(const Duration(seconds: 60));
        sub.cancel();
        async.flushMicrotasks();

        expect(planner.requests.length, greaterThan(20));
        for (final req in planner.requests) {
          // (1) 목적지는 center 500m 경계 안에서만 뽑힌다.
          expect(
            distance.distance(center, req.to),
            lessThanOrEqualTo(500 + 0.5),
          );
          // (2) 현 위치에서 50~300m 떨어진 지점이다(과요청 방지 하한 포함).
          final hop = distance.distance(req.from, req.to);
          expect(hop, greaterThanOrEqualTo(50 - 0.5));
          expect(hop, lessThanOrEqualTo(300 + 0.5));
        }
      });
    });

    test('구독 취소 후에는 더 이상 방출하지 않는다(타이머 정리)', () {
      fakeAsync((async) {
        final service = FakeNearbyUsersService(
          random: Random(1),
          tickInterval: _tick,
          routePlanner: _FakeRoutePlanner(),
        );

        final received = <List<NearbyUser>>[];
        final sub =
            service.watchNearbyUsers(center, _roster).listen(received.add);
        async.elapse(_tick * 5);
        sub.cancel();
        async.flushMicrotasks();
        final countAfterCancel = received.length;
        expect(countAfterCancel, greaterThan(0));

        // 취소 이후 충분히 시간이 흘러도 방출 수가 늘지 않는다.
        async.elapse(_tick * 10);
        expect(received.length, countAfterCancel);
      });
    });
  });
}
