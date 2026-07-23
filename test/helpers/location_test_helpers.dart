import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Override 타입은 flutter_riverpod 기본 배럴에 없고 misc.dart가 공개 export한다.
// pumpMapScreenWithService의 extraOverrides 파라미터 타입용.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gps_meeting_app/core/router/app_router.dart';
import 'package:gps_meeting_app/features/auth/models/auth_user.dart';
import 'package:gps_meeting_app/features/auth/providers/auth_providers.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:gps_meeting_app/features/map/providers/location_provider.dart';
import 'package:gps_meeting_app/features/map/providers/nearby_users_provider.dart';
import 'package:gps_meeting_app/features/map/providers/user_profiles_provider.dart';
import 'package:gps_meeting_app/features/map/screens/map_screen.dart';
import 'package:gps_meeting_app/main.dart';
import 'package:latlong2/latlong.dart';

/// 서브미터 거리 비교/좌표 생성을 위해 미터 반올림을 끈 공용 거리 계산기.
///
/// FakeNearbyUsersService와 동일한 설정으로, 기준점에서 정확한 거리의 좌표를
/// 만들거나 이동 거리를 검증할 때 쓴다.
const testDistance = Distance(roundResult: false);

/// [userAt]의 기본 중심점(서울시청 부근). 여러 테스트가 공유하는 기준점이다.
const testCenter = LatLng(37.5665, 126.9780);

/// [center]에서 정북(0도) 방향으로 [meters]만큼 떨어진 근처 사용자를 만든다.
///
/// id와 name을 동일하게 두어, 스낵바 등에서 이름으로 검증하기 쉽게 한다.
/// [center]를 생략하면 [testCenter]를 기준으로 삼는다.
NearbyUser userAt(String id, double meters, {LatLng? center}) => NearbyUser(
      id: id,
      name: id,
      position: testDistance.offset(center ?? testCenter, meters, 0),
    );

/// 테스트용 위치 좌표를 만드는 헬퍼.
Position fakePosition(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// 주어진 fake 서비스로 MapScreen 을 감싼 테스트 앱을 펌프한다.
///
/// map_screen_test.dart와 encounter_effects_layer_test.dart가 verbatim 동일한
/// 사본을 각자 들고 있던 것을, 사본 동기화 부담을 없애려고 공용 헬퍼로 추출했다.
///
/// [nearbyStream]을 주면 근처 사용자 서비스를 그 스트림으로 override한다.
/// 지정하지 않으면, 실제 주기 타이머(pending timer)를 만들지 않도록 아무것도
/// 방출하지 않는 스트림으로 override한다.
///
/// [extraOverrides]를 주면 고정 override 뒤에 이어 붙인다. 조우 판정 detector의
/// dwell을 줄이는 등, 특정 테스트만 필요한 override를 끼워 넣는 데 쓴다.
///
/// 프로필은 실제 Firebase에 닿지 않도록 [defaultNearbyUsers]로 override한다
/// (근처 사용자 시뮬레이션은 프로필 로드가 완료되어야 시작되기 때문).
Future<void> pumpMapScreenWithService(
  WidgetTester tester,
  FakeLocationService service, {
  Stream<List<NearbyUser>>? nearbyStream,
  List<Override> extraOverrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(service),
        nearbyUsersServiceProvider.overrideWithValue(
          ControlledNearbyUsersService(
            nearbyStream ?? const Stream<List<NearbyUser>>.empty(),
          ),
        ),
        userProfilesProvider.overrideWith((ref) async => defaultNearbyUsers),
        ...extraOverrides,
      ],
      child: MaterialApp(
        home: MapScreen(tileProvider: FakeTileProvider()),
      ),
    ),
  );
}

/// [finder]가 나타날 때까지 최대 [maxPumps]회 pump한다.
///
/// 스플래시/지도 로딩 뷰의 CircularProgressIndicator가 무한 애니메이션이라
/// pumpAndSettle은 영원히 settle하지 못하고 타임아웃된다. 대신 유한 횟수만
/// pump하며 원하는 위젯 등장을 기다린다.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 20,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (finder.evaluate().isNotEmpty) break;
    await tester.pump(const Duration(milliseconds: 100));
  }
  // 위젯이 등장한 직후는 페이지 전환 애니메이션(~300ms) 도중이라 이전 페이지가
  // 아직 트리에 남아 있다. 전환을 마저 끝내 findsNothing 단언이 안정되게 한다.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

/// [MyApp]을 라우터 테스트에 필요한 4종 override와 함께 펌프한다.
///
/// - [authStream]: 인증 상태 스트림. 미지정 시 미로그인(`null`)을 방출한다.
///   Stream.error를 넘기면 에러 경로(스플래시 복구 UI)도 그대로 검증할 수 있다.
/// - [positionStream]: 위치 스트림. 미지정 시 아무것도 방출하지 않는 빈 스트림.
///   지도 화면이 뜨지 않아 위치 스트림에 리스너가 붙지 않는 테스트는, 단일 구독
///   컨트롤러가 리스너 없이 close()되지 않아 teardown이 멈추므로 broadcast
///   StreamController의 stream을 넘겨야 한다.
/// - [requireLogin]: 로그인 요구 여부. 기본 true라 기존 인증 흐름 테스트는 무수정
///   통과한다. false를 주면 인증 배선을 생략하고 바로 지도로 진입하는 우회 모드를
///   검증한다.
///
/// 프로필은 실제 Firebase에 닿지 않도록 [defaultNearbyUsers]로 override한다.
Future<void> pumpApp(
  WidgetTester tester, {
  Stream<AuthUser?>? authStream,
  Stream<Position>? positionStream,
  bool requireLogin = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requireLoginProvider.overrideWithValue(requireLogin),
        authStateChangesProvider
            .overrideWith((ref) => authStream ?? Stream.value(null)),
        locationServiceProvider.overrideWithValue(
          FakeLocationService(positionStream ?? const Stream<Position>.empty()),
        ),
        nearbyUsersServiceProvider.overrideWithValue(
          ControlledNearbyUsersService(const Stream<List<NearbyUser>>.empty()),
        ),
        userProfilesProvider.overrideWith((ref) async => defaultNearbyUsers),
      ],
      child: const MyApp(),
    ),
  );
}

/// 주입한 스트림을 그대로 반환하는 fake 위치 서비스.
///
/// [openAppSettings]/[openLocationSettings] 호출 여부를 기록하여
/// 오류 뷰의 조치 버튼 동작을 검증할 수 있다.
class FakeLocationService implements LocationService {
  FakeLocationService(this._stream);

  final Stream<Position> _stream;

  /// [openAppSettings] 호출 횟수.
  int openAppSettingsCallCount = 0;

  /// [openLocationSettings] 호출 횟수.
  int openLocationSettingsCallCount = 0;

  @override
  Stream<Position> getPositionStream() => _stream;

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCallCount++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCallCount++;
    return true;
  }
}

/// 주입한 스트림을 그대로 반환하는 fake 근처 사용자 서비스.
///
/// 실제 주기 타이머 대신 테스트가 직접 제어하는 [StreamController] 스트림을
/// 주입하여, 위젯 테스트에서 pending timer 오류 없이 마커 갱신을 검증한다.
/// roster는 무시한다(테스트는 스트림으로 직접 사용자를 방출한다).
class ControlledNearbyUsersService implements NearbyUsersService {
  ControlledNearbyUsersService(this._stream);

  final Stream<List<NearbyUser>> _stream;

  @override
  Stream<List<NearbyUser>> watchNearbyUsers(
    LatLng center,
    List<NearbyUser> roster,
  ) =>
      _stream;
}

/// 네트워크 요청 없이 투명 이미지를 반환하는 테스트용 타일 프로바이더.
///
/// 실제 OSM 타일을 요청하면 위젯 테스트가 불안정해지므로 이를 우회한다.
class FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(TileProvider.transparentImage);
  }
}
