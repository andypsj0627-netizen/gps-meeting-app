import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';

/// 경로 계산 결과.
///
/// [isFallback]으로 "실제 도로 경로"와 "실패 시 직선 폴백"을 구분한다.
/// [isFallback]이 true이면 [points]의 직선은 걷기 위한 경로가 아니라 실패
/// 신호다. 호출 측은 이 직선을 따라 걷지 않고(직선은 건물/산을 관통하므로)
/// 백오프를 조정한 뒤 다르게 대응한다.
class RouteResult {
  const RouteResult({required this.points, this.isFallback = false});

  /// 경로 폴리라인(경유점 목록). 항상 2개 이상이어야 한다.
  ///
  /// [isFallback]이 true이면 이 값은 `[from, to]` 직선이며, 걷기 위한 경로가
  /// 아니라 실패를 알리는 신호로만 쓴다.
  final List<LatLng> points;

  /// 실패로 인해 직선 폴백 경로가 반환되었는지 여부.
  final bool isFallback;
}

/// 두 지점 사이의 보행 경로(폴리라인)를 계산하는 추상화.
///
/// 시뮬레이션이 건물/공터를 가로지르지 않고 실제 길을 따라 걷도록 하기 위해
/// 사용한다. 구현체 교체(다른 라우팅 API, 오프라인 그래프 등)를 대비해
/// 인터페이스로 분리한다.
abstract class RoutePlanner {
  /// [from]에서 [to]까지의 경로를 계산한다.
  ///
  /// 구현체는 실패 시 예외를 던지지 말고 직선 경로 `[from, to]`에
  /// `isFallback: true`를 담아 반환해야 한다. 예외를 던지면 worker가
  /// requestingRoute 상태에서 영영 멈추기 때문이다.
  ///
  /// 이 폴백 폴리라인은 예외 없이 실패를 알리는 신호 수단일 뿐, 따라 걷는
  /// 경로가 아니다. 이후 처리는 호출 측이 결정한다(현재: 백오프 후 재선택).
  Future<RouteResult> planRoute(LatLng from, LatLng to);
}

/// OSRM 공개 서버(FOSSGIS 보행자 프로필)를 호출하는 [RoutePlanner] 구현체.
///
/// 인도/산책로를 따르는 실제 보행 경로를 반환한다. 과거 사용하던
/// router.project-osrm.org 데모는 car 프로필만 호스팅해 마커가 자동차용
/// 터널로 산을 통과하는 문제가 있었다.
///
/// 네트워크 오류, 타임아웃, 비정상 응답, 빈 경로 등 어떤 실패가 발생해도
/// 예외 대신 직선 폴백(`isFallback: true`)을 반환한다.
class OsrmRoutePlanner implements RoutePlanner {
  OsrmRoutePlanner({
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  /// 테스트에서 MockClient를 주입하기 위한 지점.
  final http.Client _client;

  /// HTTP 요청 타임아웃. 초과 시 직선 폴백을 반환한다.
  final Duration timeout;

  /// 내부 HTTP 클라이언트를 정리한다. 더 이상 경로를 요청하지 않을 때 호출한다.
  void dispose() => _client.close();

  @override
  Future<RouteResult> planRoute(LatLng from, LatLng to) async {
    // 실패 시 항상 반환할 직선 폴백 경로.
    final fallback = RouteResult(points: [from, to], isFallback: true);
    try {
      // OSRM 좌표 순서는 "경도,위도" — LatLng와 반대이므로 주의.
      final uri = Uri.parse(
        '${AppConstants.osrmRouteBaseUrl}'
        '/${from.longitude},${from.latitude}'
        ';${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) return fallback;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List<dynamic>;
      final geometry =
          (routes[0] as Map<String, dynamic>)['geometry']
              as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      if (coordinates.length < 2) return fallback;

      return RouteResult(
        points: [
          // GeoJSON 좌표는 [lon, lat] 순서 — LatLng(lat, lon)으로 뒤집는다.
          for (final coord in coordinates.cast<List<dynamic>>())
            LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble()),
        ],
      );
    } catch (_) {
      // 파싱 실패/네트워크 오류/타임아웃 모두 직선 폴백으로 흡수한다.
      return fallback;
    }
  }
}
