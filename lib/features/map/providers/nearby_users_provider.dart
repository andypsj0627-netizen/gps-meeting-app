import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../models/nearby_user.dart';
import 'location_provider.dart';
import 'user_profiles_provider.dart';

/// 시뮬레이션 사용자 수.
const int _simUserCount = 5;

/// 최초 배치 반경(미터) — 내 위치 주변 이 반경 안에 무작위로 배치한다.
const double _spawnRadiusMeters = 200;

/// 활동 반경(미터) — 이 밖으로 벗어나면 다시 안쪽으로 향한다.
const double _boundaryRadiusMeters = 300;

/// 한 스텝 이동 거리 범위(미터).
const double _stepMinMeters = 5;
const double _stepMaxMeters = 15;

/// 랜덤 워크 갱신 주기.
const Duration _tickInterval = Duration(seconds: 1);

/// 거리/방위 계산기. Distance는 불변이라 전역 상수로 재사용한다.
const Distance _distance = Distance();

/// 화면에 표시할 시뮬레이션 사용자 1명의 상태.
class SimulatedUser {
  const SimulatedUser({
    required this.profile,
    required this.position,
    required this.encountered,
  });

  /// 사용자 프로필(이름/나이/성별 등).
  final NearbyUser profile;

  /// 현재 좌표.
  final LatLng position;

  /// 조우 여부. 한 번 true가 되면 계속 유지된다(sticky).
  final bool encountered;

  SimulatedUser copyWith({LatLng? position, bool? encountered}) {
    return SimulatedUser(
      profile: profile,
      position: position ?? this.position,
      encountered: encountered ?? this.encountered,
    );
  }
}

/// [center] 주변 [radiusMeters] 이내 무작위 지점을 하나 만든다.
LatLng randomPointNear(LatLng center, double radiusMeters, Random random) {
  final bearing = random.nextDouble() * 360;
  // 균등 분포에 가깝도록 반경은 sqrt로 보정한다(중심 쏠림 완화).
  final radius = sqrt(random.nextDouble()) * radiusMeters;
  return _distance.offset(center, radius, bearing);
}

/// 랜덤 워크 한 스텝. 활동 반경([_boundaryRadiusMeters])을 벗어났으면
/// [center] 쪽으로 방위를 잡고, 아니면 완전히 무작위 방위로 이동한다.
LatLng randomWalkStep(LatLng current, LatLng center, Random random) {
  final double bearing;
  if (_distance.as(LengthUnit.Meter, center, current) > _boundaryRadiusMeters) {
    // 중심 방향으로 향하되 약간의 흔들림(±45°)을 준다.
    bearing = _distance.bearing(current, center) + (random.nextDouble() - 0.5) * 90;
  } else {
    bearing = random.nextDouble() * 360;
  }
  final step = _stepMinMeters +
      random.nextDouble() * (_stepMaxMeters - _stepMinMeters);
  return _distance.offset(current, step, bearing);
}

/// 조우 판정(순수 함수).
///
/// 각 사용자에 대해 (1) 내 위치, (2) 다른 시뮬레이션 사용자와의 거리를 확인해
/// [AppConstants.encounterRadiusMeters] 이내면 조우로 본다. [already]에 이미
/// 들어 있는 id는 그대로 유지(sticky)한다. 반환값은 갱신된 조우 id 집합이다.
Set<String> computeEncounters({
  required LatLng myPosition,
  required List<SimulatedUser> users,
  required Set<String> already,
}) {
  const radiusMeters = AppConstants.encounterRadiusMeters;
  final result = Set<String>.of(already);
  for (var i = 0; i < users.length; i++) {
    final a = users[i];
    if (result.contains(a.profile.id)) continue;
    // 내 위치와의 거리.
    if (_distance.as(LengthUnit.Meter, myPosition, a.position) <= radiusMeters) {
      result.add(a.profile.id);
      continue;
    }
    // 다른 시뮬레이션 사용자와의 거리.
    for (var j = 0; j < users.length; j++) {
      if (i == j) continue;
      if (_distance.as(LengthUnit.Meter, a.position, users[j].position) <=
          radiusMeters) {
        result.add(a.profile.id);
        break;
      }
    }
  }
  return result;
}

/// 내 위치 주변에서 랜덤 워크하는 시뮬레이션 사용자들을 관리하는 notifier.
///
/// 내 위치의 첫 값이 도착하면 프로필 5명을 주변에 배치하고, 이후 주기적으로
/// 이동시키며 조우 여부를 갱신한다. dispose 시 타이머를 정리한다.
class NearbyUsersNotifier extends Notifier<List<SimulatedUser>> {
  Timer? _timer;
  final Random _random = Random();
  late LatLng _center;
  LatLng _myPosition = const LatLng(0, 0);
  Set<String> _encountered = {};

  @override
  List<SimulatedUser> build() {
    ref.onDispose(() => _timer?.cancel());

    // 프로필이 아직 로딩 중이면 스폰하지 않는다. 여기서 defaultNearbyUsers로
    // 먼저 스폰하면, Firestore future가 뒤늦게 resolve될 때 build가 재실행되어
    // 5명 전원이 새 위치로 텔레포트하고 조우 상태(_encountered)가 초기화된다.
    // userProfilesProvider는 내부 catch로 항상 settle되므로 무한 로딩은 없다.
    final profilesAsync = ref.watch(userProfilesProvider);
    if (profilesAsync.isLoading) return const [];
    final profiles = profilesAsync.value ?? defaultNearbyUsers;

    // 내 위치가 아직 없으면 배치할 기준점이 없으므로 빈 목록.
    // 위치가 생기면(첫 값) build가 다시 실행되어 배치한다.
    final hasPosition =
        ref.watch(positionStreamProvider.select((s) => s.value != null));
    if (!hasPosition) return const [];

    final position = ref.read(positionStreamProvider).value!;
    _center = LatLng(position.latitude, position.longitude);
    _myPosition = _center;

    // 이후 내 위치 갱신은 조우 판정용으로만 추적한다(재배치 없이).
    ref.listen<AsyncValue<Position>>(positionStreamProvider, (_, next) {
      final p = next.value;
      if (p != null) _myPosition = LatLng(p.latitude, p.longitude);
    });

    final selected = profiles.take(_simUserCount).toList();

    final spawned = [
      for (final profile in selected)
        SimulatedUser(
          profile: profile,
          position: randomPointNear(_center, _spawnRadiusMeters, _random),
          encountered: false,
        ),
    ];

    // 스폰 직후 한 번 조우를 판정한다. 그러지 않으면 30m 이내에 스폰된
    // 사용자도 첫 틱(1초)까지 비조우(회색/탭 불가)로 렌더된다.
    _encountered = computeEncounters(
      myPosition: _myPosition,
      users: spawned,
      already: const {},
    );
    final initial = [
      for (final user in spawned)
        user.copyWith(encountered: _encountered.contains(user.profile.id)),
    ];

    // 주기적 랜덤 워크 시작.
    _timer?.cancel();
    _timer = Timer.periodic(_tickInterval, (_) => _tick());

    return initial;
  }

  /// 한 틱: 모두 이동시킨 뒤 조우를 재판정한다.
  void _tick() {
    final moved = [
      for (final user in state)
        user.copyWith(
          position: randomWalkStep(user.position, _center, _random),
        ),
    ];
    _encountered = computeEncounters(
      myPosition: _myPosition,
      users: moved,
      already: _encountered,
    );
    state = [
      for (final user in moved)
        user.copyWith(encountered: _encountered.contains(user.profile.id)),
    ];
  }
}

/// 시뮬레이션 사용자 목록 provider.
///
/// autoDispose: 지도 화면이 사라지면 1초 랜덤 워크 타이머도 함께 정리된다.
final nearbyUsersProvider =
    NotifierProvider.autoDispose<NearbyUsersNotifier, List<SimulatedUser>>(
  NearbyUsersNotifier.new,
);
