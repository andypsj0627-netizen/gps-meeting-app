import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../models/encounter_event.dart';
import '../models/nearby_user.dart';
import '../providers/encounter_provider.dart';
import '../providers/location_provider.dart';
import '../providers/nearby_users_provider.dart';
import '../utils/position_latlng.dart';

/// 화면이 표시할 상위 단계.
///
/// [hasValue]가 최우선이라 일시적 오류가 발생해도 이전 위치 데이터가 있으면
/// 지도를 계속 표시한다. 그다음 로딩, 마지막으로 오류를 표시한다.
enum _MapPhase { data, loading, error }

_MapPhase _phaseOf(AsyncValue<Position> state) {
  if (state.hasValue) return _MapPhase.data;
  if (state.isLoading) return _MapPhase.loading;
  return _MapPhase.error;
}

/// 카메라 follow를 해제해야 하는 사용자 제스처 소스 집합.
///
/// 사용자가 직접 팬/줌/회전하면 follow를 끄고 사용자의 시점을 존중한다.
/// 프로그래매틱 이동([MapEventSource.mapController])이나 화면 크기 변경 등은
/// 여기에 포함하지 않아, 우리 코드의 follow 이동이 스스로를 해제하지 않게 한다.
const Set<MapEventSource> _userGestureSources = {
  MapEventSource.dragStart,
  MapEventSource.onDrag,
  MapEventSource.dragEnd,
  MapEventSource.multiFingerGestureStart,
  MapEventSource.onMultiFinger,
  MapEventSource.multiFingerEnd,
  MapEventSource.doubleTap,
  MapEventSource.doubleTapHold,
  MapEventSource.doubleTapZoomAnimationController,
  MapEventSource.flingAnimationController,
  MapEventSource.scrollWheel,
  MapEventSource.cursorKeyboardRotation,
  MapEventSource.keyboard,
};

/// 지도 화면.
///
/// 내 위치를 실시간으로 추적하여 마커와 카메라를 위치 스트림에 맞춰 이동시킨다.
/// follow 모드일 때만 카메라가 위치를 따라가며, 사용자가 지도를 조작하면
/// follow를 해제한다. 상태에 따라 (1) 지도, (2) 로딩, (3) 오류 뷰를 표시한다.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.tileProvider});

  /// 위젯 테스트에서 실제 네트워크 타일 요청을 우회하기 위한 주입 지점.
  ///
  /// null이면 flutter_map 기본 네트워크 타일 프로바이더를 사용한다.
  final TileProvider? tileProvider;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  /// 카메라가 현재 위치를 따라가는지 여부. 초기값은 true(추적 시작).
  bool _following = true;

  @override
  void dispose() {
    // flutter_map은 외부에서 주입한 컨트롤러를 dispose하지 않으므로 직접 정리한다.
    _mapController.dispose();
    super.dispose();
  }

  /// follow 모드를 켜고, 마지막 위치로 현재 줌을 유지한 채 즉시 이동한다.
  void _startFollowing() {
    final position = ref.read(positionStreamProvider).value;
    setState(() => _following = true);
    if (position != null) {
      _mapController.move(
        position.latLng,
        // initialZoom으로 리셋하지 않고 현재 줌을 유지한다.
        _mapController.camera.zoom,
      );
    }
  }

  /// 사용자 제스처를 감지하면 follow를 해제한다.
  void _onMapEvent(MapEvent event) {
    if (_following && _userGestureSources.contains(event.source)) {
      setState(() => _following = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 새 위치를 수신할 때마다 follow 모드일 때만 카메라를 이동시킨다.
    // 첫 위치는 FlutterMap의 initialCenter가 처리하므로, 이전 데이터가 없던
    // 첫 이벤트는 이동을 건너뛴다. flutter_map 8.x는 외부 컨트롤러의 카메라를
    // initState에서 동기 초기화하므로 여기서 별도의 예외 방어는 필요 없다.
    ref.listen<AsyncValue<Position>>(positionStreamProvider, (previous, next) {
      final position = next.value;
      if (position == null) return;
      // 첫 위치(이전 데이터 없음)는 initialCenter가 처리한다.
      if (previous?.value == null) return;
      if (!mounted || !_following) return;
      _mapController.move(
        position.latLng,
        // 현재 줌을 유지하여 5m마다 줌이 리셋되지 않게 한다.
        _mapController.camera.zoom,
      );
    });

    // 위치 이벤트마다 전체가 리빌드되지 않도록, 부모는 상태 전이(phase)만 구독한다.
    // 실제 마커 좌표는 아래 _MarkerLayer가 별도로 구독해 마커만 리빌드된다.
    final phase = ref.watch(positionStreamProvider.select(_phaseOf));

    // 조우 이벤트 배치가 방출될 때마다 스낵바로 알린다. 한 재계산에서 여러 명이
    // 동시에 진입하면 한 배치로 오므로 스낵바 1개에 이름을 모아 표시하고, 배치가
    // 연달아 오면 이전 스낵바를 즉시 감춰 최신 조우가 항상 보이게 한다.
    //
    // data phase(내 위치 확보됨)에서만 구독한다. 조우 감지 체인은 근처 사용자
    // 스트림을 활성화하고, 그 스트림은 최초 내 위치([positionStreamProvider.future])를
    // 기다린다. 로딩/오류 단계에서 미리 활성화하면 위치 미확보 상태로 화면을
    // 벗어날 때 provider가 정리되며 오류가 나므로, 지도가 떠 있는 동안만 듣는다.
    if (phase == _MapPhase.data) {
      ref.listen<AsyncValue<List<EncounterEvent>>>(encounterEventsProvider,
          (previous, next) {
        final events = next.value;
        if (events == null || events.isEmpty || !mounted) return;
        // 1명은 정확한 거리까지, 여러 명은 이름만 이어 붙여 한 문장으로 만든다.
        final message = events.length == 1
            ? '${events.single.user.name}님과 ${events.single.distanceMeters.round()}m 거리에서 만났어요!'
            : '${events.map((e) => e.user.name).join(', ')}님과 가까운 거리에서 만났어요!';
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(
              message,
              key: const ValueKey('encounter_snackbar_text'),
            ),
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      floatingActionButton: phase == _MapPhase.data
          ? FloatingActionButton(
              key: const ValueKey('follow_button'),
              onPressed: _startFollowing,
              tooltip: '내 위치로 이동',
              child: const Icon(Icons.my_location),
            )
          : null,
      body: switch (phase) {
        // (1) 위치 수신됨 → 지도 + 마커 (일시적 오류에도 이전 데이터로 유지)
        _MapPhase.data => _MapView(
            mapController: _mapController,
            initialCenter: _initialCenter(),
            onMapEvent: _onMapEvent,
            tileProvider: widget.tileProvider,
          ),
        // (2) 권한 요청 중 / 최초 위치 대기 / 재시도 refresh 로딩
        _MapPhase.loading => const _LoadingView(),
        // (3) 권한 거부 또는 위치 획득 실패 → 종류별 조치 안내
        _MapPhase.error => _ErrorView(error: ref.read(positionStreamProvider).error),
      },
    );
  }

  /// 지도 진입 시점의 첫 위치(초기 중심). data phase에서만 호출되므로 non-null.
  LatLng _initialCenter() {
    return ref.read(positionStreamProvider).value!.latLng;
  }
}

/// 권한 요청 중 또는 최초 위치 수신을 대기하는 동안 표시하는 로딩 뷰.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('내 위치를 찾는 중...'),
        ],
      ),
    );
  }
}

/// 위치 획득 실패 시 안내 메시지와 종류별 조치 버튼을 표시하는 뷰.
///
/// - 영구 거부: 앱 설정 열기 + 재시도
/// - 위치 서비스 꺼짐: 위치 설정 열기 + 재시도
/// - 그 외(일시 거부/알 수 없음/기타): 재시도만
class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final err = error;
    final kind = err is LocationException ? err.kind : null;
    final message = err is LocationException
        ? err.message
        : '위치를 가져오지 못했습니다. 잠시 후 다시 시도해주세요.';

    final actions = <Widget>[];
    if (kind == LocationFailureKind.deniedForever) {
      actions.add(
        ElevatedButton(
          key: const ValueKey('open_settings_button'),
          onPressed: () => ref.read(locationServiceProvider).openAppSettings(),
          child: const Text('설정 열기'),
        ),
      );
    } else if (kind == LocationFailureKind.serviceDisabled) {
      actions.add(
        ElevatedButton(
          key: const ValueKey('open_location_settings_button'),
          onPressed: () =>
              ref.read(locationServiceProvider).openLocationSettings(),
          child: const Text('위치 설정 열기'),
        ),
      );
    }
    actions.add(
      ElevatedButton(
        key: const ValueKey('retry_button'),
        onPressed: () => ref.invalidate(positionStreamProvider),
        child: const Text('재시도'),
      ),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

/// 실제 OSM 지도와 내 위치 마커를 표시하는 뷰.
///
/// [FlutterMap] 본체는 진입 시 한 번만 구성되고, 마커 좌표만 [_MarkerLayer]가
/// 구독해 위치 갱신 시 마커만 리빌드된다.
class _MapView extends StatelessWidget {
  const _MapView({
    required this.mapController,
    required this.initialCenter,
    required this.onMapEvent,
    this.tileProvider,
  });

  final MapController mapController;
  final LatLng initialCenter;
  final MapEventCallback onMapEvent;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: AppConstants.initialZoom,
        onMapEvent: onMapEvent,
      ),
      children: [
        TileLayer(
          urlTemplate: AppConstants.osmTileUrl,
          userAgentPackageName: AppConstants.userAgentPackageName,
          // null이면 flutter_map이 기본 네트워크 프로바이더를 사용한다.
          tileProvider: tileProvider,
        ),
        const _NearbyUsersLayer(),
        const _MarkerLayer(),
      ],
    );
  }
}

/// 내 위치 마커만 구독/리빌드하는 소형 Consumer 레이어.
class _MarkerLayer extends ConsumerWidget {
  const _MarkerLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position =
        ref.watch(positionStreamProvider.select((state) => state.value));
    if (position == null) return const MarkerLayer(markers: []);
    final latLng = position.latLng;
    return MarkerLayer(
      markers: [
        Marker(
          key: const ValueKey('my_location_marker'),
          point: latLng,
          width: 40,
          height: 40,
          child: Icon(
            Icons.my_location,
            color: Theme.of(context).colorScheme.primary,
            size: 32,
          ),
        ),
      ],
    );
  }
}

/// 가상 근처 사용자(A/B/C) 마커만 구독/리빌드하는 소형 Consumer 레이어.
///
/// 로딩 중이거나 오류가 발생하면 빈 레이어를 반환하여, 내 위치 지도 표시를
/// 방해하지 않는다(근처 사용자 시뮬레이션은 어디까지나 보조 정보다).
/// [AsyncValue.unwrapPrevious]로 이전 데이터를 벗겨내므로, 오류 상태에서
/// 낡은 목록의 유령 마커가 남지 않는다.
class _NearbyUsersLayer extends ConsumerWidget {
  const _NearbyUsersLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(
      nearbyUsersProvider.select((state) => state.unwrapPrevious().value),
    );
    if (users == null) return const MarkerLayer(markers: []);
    return MarkerLayer(
      markers: [
        for (final user in users)
          Marker(
            key: ValueKey('nearby_user_marker_${user.id}'),
            point: user.position,
            width: 40,
            height: 40,
            child: _NearbyUserMarker(user: user),
          ),
      ],
    );
  }
}

/// 근처 사용자 한 명을 나타내는 이니셜 원형 마커.
class _NearbyUserMarker extends StatelessWidget {
  const _NearbyUserMarker({required this.user});

  final NearbyUser user;

  /// 마커 색상 팔레트. 사용자 id 해시로 골라 인원이 늘어도 안전하게 순환한다.
  static const List<Color> _palette = [
    Color(0xFFE53935), // red
    Color(0xFF43A047), // green
    Color(0xFF1E88E5), // blue
    Color(0xFF8E24AA), // purple
    Color(0xFFFB8C00), // orange
  ];

  @override
  Widget build(BuildContext context) {
    // Dart의 % 연산은 항상 음이 아닌 나머지를 반환하므로 hashCode 부호는 무관하다.
    final color = _palette[user.id.hashCode % _palette.length];
    return CircleAvatar(
      backgroundColor: color,
      child: Text(
        user.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
