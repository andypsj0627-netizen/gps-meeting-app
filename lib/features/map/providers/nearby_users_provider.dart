import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/nearby_user.dart';
import '../services/route_planner.dart';
import '../utils/position_latlng.dart';
import 'location_provider.dart';

/// 근처 사용자 목록을 스트림으로 제공하는 서비스 추상화.
///
/// 현재는 [FakeNearbyUsersService]가 가상 사용자를 시뮬레이션하지만,
/// Phase 3에서 Firestore 지오쿼리 기반 구현체로 교체될 인터페이스다.
/// 화면/Provider 계층은 이 추상화에만 의존하므로 구현 교체 시 영향이 없다.
abstract class NearbyUsersService {
  /// [center] 주변의 근처 사용자 목록을 실시간으로 방출한다.
  ///
  /// 스트림 구독이 취소되면 내부 리소스(타이머 등)를 정리해야 한다.
  Stream<List<NearbyUser>> watchNearbyUsers(LatLng center);
}

/// 가상 사용자 한 명의 생명주기 단계.
enum _WalkerPhase {
  /// 경로 계산 응답을 기다리는 중 — 제자리 대기.
  requestingRoute,

  /// 계산된 폴리라인을 따라 걷는 중.
  walking,

  /// 목적지 도착 후 잠시 쉬는 중. 대기가 끝나면 새 목적지를 뽑는다.
  waiting,
}

/// 가상의 근처 사용자(A/B/C)가 실제 길을 따라 걷도록 시뮬레이션하는 fake 서비스.
///
/// 실제 백엔드 없이 Phase 2 UI를 개발/시연하기 위한 구현체다.
/// 각 인물은 "목적지 선정 → 경로 요청([RoutePlanner]) → 폴리라인 보행 →
/// 도착 후 1~3초 대기"를 반복한다. 보행은 인물별 고유 속도(기본 1.1~1.5m/s)로
/// 폴리라인 세그먼트 위를 선형 보간하며 전진하므로, 틱마다 순간이동하지 않고
/// 자연스럽게 움직인다.
///
/// 경로 계산이 직선 폴백([RouteResult.isFallback])으로 끝났다면 도착 후
/// 대기를 10~20초로 늘려, 장애 중인 공개 라우팅 서버를 연타하지 않는다.
///
/// [random], [tickInterval], [routePlanner], 속도 범위를 주입할 수 있어
/// 테스트에서 네트워크 없이 결정적으로 동작한다.
class FakeNearbyUsersService implements NearbyUsersService {
  FakeNearbyUsersService({
    Random? random,
    this.tickInterval = const Duration(milliseconds: 300),
    RoutePlanner? routePlanner,
    this.minSpeed = 1.1,
    this.maxSpeed = 1.5,
  })  : _random = random ?? Random(),
        _routePlanner = routePlanner ?? OsrmRoutePlanner();

  final Random _random;

  /// 시뮬레이션 한 스텝(틱)의 주기.
  final Duration tickInterval;

  /// 목적지까지의 보행 경로를 계산하는 플래너.
  final RoutePlanner _routePlanner;

  /// 보행 속도 하한(m/s). 인물별 속도는 spawn 시 [minSpeed]~[maxSpeed]에서 뽑는다.
  final double minSpeed;

  /// 보행 속도 상한(m/s).
  final double maxSpeed;

  /// 거리/방위 계산기. latlong2의 구면 계산을 사용한다.
  ///
  /// 틱당 이동거리가 1m 미만이므로, 기본값인 미터 단위 반올림을 꺼서
  /// 서브미터 정밀도를 유지한다.
  static const Distance _distance = Distance(roundResult: false);

  /// center 기준 초기 배치 최소 반경(m).
  static const double _minSpawnRadius = 100;

  /// center 기준 초기 배치 최대 반경(m).
  static const double _maxSpawnRadius = 300;

  /// 목적지는 항상 center에서 이 반경(m) 안에서만 고른다.
  ///
  /// 이 경계는 "목적지 선정 시점"의 보장이다. 두 지점을 잇는 실제 도로 경로는
  /// 이 반경을 다소 벗어나는 구간을 지날 수 있다.
  static const double _boundaryRadius = 500;

  /// 현재 위치 기준 목적지 선정 최소 거리(m). 너무 가까운 목적지가 뽑혀
  /// 경로 요청이 잦아지는 것(공개 서버 과요청)을 막는다.
  static const double _minDestinationDistance = 50;

  /// 현재 위치 기준 목적지 선정 최대 거리(m).
  static const double _maxDestinationDistance = 300;

  /// 배치할 가상 사용자 이름 목록.
  static const List<String> _names = ['A', 'B', 'C'];

  @override
  Stream<List<NearbyUser>> watchNearbyUsers(LatLng center) {
    late final StreamController<List<NearbyUser>> controller;
    Timer? timer;
    // 구독 취소 후 도착하는 경로 응답을 무시하기 위한 플래그.
    var cancelled = false;
    late List<_WalkingUser> walkers;

    // 한 틱 동안 걷는 시간(초). 틱당 이동거리 = 속도(m/s) × 이 값.
    final tickSeconds =
        tickInterval.inMicroseconds / Duration.microsecondsPerSecond;

    List<NearbyUser> snapshot() => [for (final w in walkers) w.toModel()];

    /// 새 목적지를 뽑고 경로 계산을 시작한다. 응답까지는 제자리 대기.
    void requestRoute(_WalkingUser w) {
      w.phase = _WalkerPhase.requestingRoute;
      final destination = _pickDestination(center, w.position);
      _routePlanner.planRoute(w.position, destination).then((result) {
        if (cancelled) return;
        // 플래너 계약상 최소 [from, to]가 오지만, 방어적으로 한 번 더 보정한다.
        w.route = result.points.length >= 2
            ? result.points
            : [w.position, destination];
        w.routeWasFallback = result.isFallback;
        w.segmentIndex = 0;
        w.phase = _WalkerPhase.walking;
      });
    }

    /// 도착 처리: 랜덤 대기 상태로 전환한다.
    ///
    /// 정상 경로였다면 1~3초, 직선 폴백(경로 계산 실패)이었다면 10~20초 대기해
    /// 실패 중인 라우팅 서버에 대한 재요청 빈도를 낮춘다(백오프).
    void arrive(_WalkingUser w) {
      w.phase = _WalkerPhase.waiting;
      w.waitRemaining = w.routeWasFallback
          ? Duration(milliseconds: 10000 + _random.nextInt(10001))
          : Duration(milliseconds: 1000 + _random.nextInt(2001));
    }

    /// 폴리라인을 따라 정확히 속도×틱시간 만큼 전진한다(세그먼트 경계 이월 포함).
    void advance(_WalkingUser w) {
      final route = w.route!;
      var remaining = w.speed * tickSeconds;
      // 부동소수 잔여량으로 인한 무한루프를 막기 위해 미세 잔여는 버린다.
      while (remaining > 1e-9) {
        if (w.segmentIndex >= route.length - 1) break; // 경로 끝에 도달.
        final target = route[w.segmentIndex + 1];
        final toTarget = _distance.distance(w.position, target);
        if (toTarget <= remaining) {
          // 세그먼트 끝을 넘어감 — 다음 세그먼트로 이월.
          w.position = target;
          w.segmentIndex++;
          remaining -= toTarget;
        } else {
          // 세그먼트 위 선형 보간: 남은 거리만큼만 전진.
          w.position = _distance.offset(
            w.position,
            remaining,
            _distance.bearing(w.position, target),
          );
          remaining = 0;
        }
      }
      if (w.segmentIndex >= route.length - 1) arrive(w);
    }

    // 직전에 방출한 스냅샷. 전원이 제자리(경로 대기/휴식)인 틱에는
    // 동일한 목록을 다시 방출하지 않기 위해 기억해 둔다.
    List<NearbyUser>? lastEmitted;

    void emitIfChanged() {
      final snap = snapshot();
      if (listEquals(snap, lastEmitted)) return;
      lastEmitted = snap;
      controller.add(snap);
    }

    void tick() {
      for (final w in walkers) {
        switch (w.phase) {
          case _WalkerPhase.requestingRoute:
            break; // 경로 응답 대기 — 제자리.
          case _WalkerPhase.walking:
            advance(w);
          case _WalkerPhase.waiting:
            w.waitRemaining -= tickInterval;
            if (w.waitRemaining <= Duration.zero) requestRoute(w);
        }
      }
      emitIfChanged();
    }

    controller = StreamController<List<NearbyUser>>(
      onListen: () {
        walkers = _spawn(center);
        // 첫 방출: 초기 배치 상태를 즉시 내보내고, 곧바로 경로 계산을 시작한다.
        emitIfChanged();
        for (final w in walkers) {
          requestRoute(w);
        }
        timer = Timer.periodic(tickInterval, (_) => tick());
      },
      onCancel: () {
        cancelled = true;
        timer?.cancel();
        timer = null;
      },
    );

    return controller.stream;
  }

  /// center 기준 100~300m 반경에 A/B/C를 무작위 배치한다.
  List<_WalkingUser> _spawn(LatLng center) {
    return [
      for (final name in _names)
        _WalkingUser(
          id: 'fake_$name',
          name: name,
          position: _distance.offset(
            center,
            _minSpawnRadius +
                _random.nextDouble() * (_maxSpawnRadius - _minSpawnRadius),
            _random.nextDouble() * 360,
          ),
          speed: minSpeed + _random.nextDouble() * (maxSpeed - minSpeed),
        ),
    ];
  }

  /// 현재 위치 기준 50~300m 거리의 랜덤 지점을 목적지로 뽑는다.
  ///
  /// 목적지가 center 기준 500m 경계를 벗어나면 다시 뽑고, 확률적으로 계속
  /// 실패하는 극단적인 경우에는 center 방향의 안전한 지점으로 폴백한다.
  LatLng _pickDestination(LatLng center, LatLng from) {
    for (var attempt = 0; attempt < 30; attempt++) {
      final candidate = _distance.offset(
        from,
        _minDestinationDistance +
            _random.nextDouble() *
                (_maxDestinationDistance - _minDestinationDistance),
        _random.nextDouble() * 360,
      );
      if (_distance.distance(center, candidate) <= _boundaryRadius) {
        return candidate;
      }
    }
    return _distance.offset(from, 100, _distance.bearing(from, center));
  }
}

/// 시뮬레이션 내부에서 생명주기 상태를 함께 들고 다니는 가변 상태.
///
/// 외부에는 불변 [NearbyUser]로만 노출한다.
class _WalkingUser {
  _WalkingUser({
    required this.id,
    required this.name,
    required this.position,
    required this.speed,
  });

  final String id;
  final String name;
  LatLng position;

  /// 인물별 고유 보행 속도(m/s). spawn 시 한 번 부여되어 유지된다.
  final double speed;

  /// 현재 생명주기 단계. spawn 직후에는 경로 응답 대기부터 시작한다.
  _WalkerPhase phase = _WalkerPhase.requestingRoute;

  /// 현재 걷는 폴리라인. walking 단계에서만 non-null.
  List<LatLng>? route;

  /// 현재 [route]가 경로 계산 실패로 인한 직선 폴백인지 여부.
  /// 도착 후 대기 시간(백오프) 결정에 사용한다.
  bool routeWasFallback = false;

  /// [route]에서 현재 걷고 있는 세그먼트의 시작 인덱스.
  int segmentIndex = 0;

  /// waiting 단계의 남은 대기 시간.
  Duration waitRemaining = Duration.zero;

  NearbyUser toModel() => NearbyUser(id: id, name: name, position: position);
}

/// 근처 사용자 서비스 provider.
///
/// 기본값은 가상 시뮬레이션(OSRM 경로 기반)이며, 테스트/실서비스에서는
/// 이 provider를 override하여 구현을 교체한다.
///
/// 지도 화면을 벗어나면 시뮬레이션과 HTTP 클라이언트가 함께 정리되도록
/// autoDispose로 두고, 기본 생성 경로의 플래너를 onDispose에서 닫는다.
final nearbyUsersServiceProvider =
    Provider.autoDispose<NearbyUsersService>((ref) {
  final planner = OsrmRoutePlanner();
  ref.onDispose(planner.dispose);
  return FakeNearbyUsersService(routePlanner: planner);
});

/// 근처 사용자 목록을 실시간으로 방출하는 스트림 provider.
///
/// 최초 내 위치 1회만을 시뮬레이션 앵커(center)로 사용한다.
/// [positionStreamProvider]를 watch하면 위치가 5m 이동할 때마다 이 provider가
/// 재실행되어 시뮬레이션이 매번 리셋되므로, `read(...future)`로 첫 위치만 읽는다.
///
/// [locationServiceProvider]와 마찬가지로 Riverpod의 자동 재시도를 끈다.
final nearbyUsersProvider = StreamProvider.autoDispose<List<NearbyUser>>(
  (ref) async* {
    // 서비스는 await 이전에 동기적으로 watch하여 의존성을 정확히 추적한다.
    final service = ref.watch(nearbyUsersServiceProvider);
    final position = await ref.read(positionStreamProvider.future);
    yield* service.watchNearbyUsers(position.latLng);
  },
  retry: (retryCount, error) => null,
);
