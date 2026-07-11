import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/map/services/route_planner.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const from = LatLng(37.5665, 126.9780);
  const to = LatLng(37.5700, 126.9820);

  group('OsrmRoutePlanner', () {
    test('정상 응답의 [lon, lat] 좌표를 LatLng(lat, lon)으로 파싱한다', () async {
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'geometry': {
                  'type': 'LineString',
                  // GeoJSON은 [lon, lat] 순서.
                  'coordinates': [
                    [126.9780, 37.5665],
                    [126.9800, 37.5680],
                    [126.9820, 37.5700],
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final planner = OsrmRoutePlanner(client: client);

      final result = await planner.planRoute(from, to);

      expect(result.isFallback, isFalse);
      expect(result.points.length, 3);
      expect(result.points[0], const LatLng(37.5665, 126.9780));
      expect(result.points[1], const LatLng(37.5680, 126.9800));
      expect(result.points[2], const LatLng(37.5700, 126.9820));
      // 요청 URL도 "경도,위도;경도,위도" 순서여야 한다.
      expect(requestedUri!.path, contains('126.978,37.5665;126.982,37.57'));
    });

    test('비정상 상태코드면 직선 폴백 [from, to]를 반환한다', () async {
      final client = MockClient(
        (request) async => http.Response('Internal Server Error', 500),
      );
      final planner = OsrmRoutePlanner(client: client);

      final result = await planner.planRoute(from, to);

      expect(result.points, [from, to]);
      expect(result.isFallback, isTrue);
    });

    test('네트워크 예외가 발생해도 직선 폴백을 반환한다', () async {
      final client = MockClient(
        (request) async => throw http.ClientException('연결 실패'),
      );
      final planner = OsrmRoutePlanner(client: client);

      final result = await planner.planRoute(from, to);

      expect(result.points, [from, to]);
      expect(result.isFallback, isTrue);
    });

    test('응답 본문이 기대 구조가 아니면 직선 폴백을 반환한다', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'code': 'NoRoute'}), 200),
      );
      final planner = OsrmRoutePlanner(client: client);

      final result = await planner.planRoute(from, to);

      expect(result.points, [from, to]);
      expect(result.isFallback, isTrue);
    });

    test('경로 좌표가 2개 미만이면 직선 폴백을 반환한다', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'geometry': {
                  'type': 'LineString',
                  'coordinates': [
                    [126.9780, 37.5665],
                  ],
                },
              },
            ],
          }),
          200,
        ),
      );
      final planner = OsrmRoutePlanner(client: client);

      final result = await planner.planRoute(from, to);

      expect(result.points, [from, to]);
      expect(result.isFallback, isTrue);
    });
  });
}
