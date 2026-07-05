import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gps_meeting_app/features/map/providers/location_provider.dart';
import 'package:gps_meeting_app/main.dart';

import 'helpers/location_test_helpers.dart';

void main() {
  testWidgets('앱 루트가 라우터/테마/ProviderScope를 통해 지도 화면을 표시한다',
      (tester) async {
    // 위치를 방출하지 않는 스트림 → 로딩 상태 유지(네트워크 타일 요청 없음).
    final controller = StreamController<Position>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationServiceProvider
              .overrideWithValue(FakeLocationService(controller.stream)),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    // 라우터가 '/' 를 지도 화면에 연결하고, AppBar 제목이 렌더링된다.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('GPS 모임'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
