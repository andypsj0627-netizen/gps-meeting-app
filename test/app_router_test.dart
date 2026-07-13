import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gps_meeting_app/features/auth/models/auth_user.dart';
import 'package:gps_meeting_app/features/auth/screens/login_screen.dart';
import 'package:gps_meeting_app/features/map/screens/map_screen.dart';

import 'helpers/location_test_helpers.dart';

void main() {
  testWidgets('미로그인 상태면 로그인 화면을 표시한다', (tester) async {
    // 이 테스트에서는 지도 화면이 빌드되지 않아 위치 스트림에 리스너가 붙지
    // 않는다. 단일 구독 컨트롤러는 리스너 없이 close()가 완료되지 않아
    // teardown이 영원히 대기하므로 broadcast를 쓴다.
    final controller = StreamController<Position>.broadcast();
    addTearDown(controller.close);

    await pumpApp(tester, positionStream: controller.stream);
    await pumpUntilFound(tester, find.byType(LoginScreen));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MapScreen), findsNothing);
  });

  testWidgets('로그인 상태면 지도 화면을 표시한다', (tester) async {
    final controller = StreamController<Position>();
    addTearDown(controller.close);

    await pumpApp(
      tester,
      authStream: Stream.value(const AuthUser(uid: 'u', email: 'e@e.com')),
      positionStream: controller.stream,
    );
    await pumpUntilFound(tester, find.byType(MapScreen));

    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('로그인 이벤트가 오면 로그인 화면에서 지도 화면으로 전환된다',
      (tester) async {
    final positionController = StreamController<Position>();
    addTearDown(positionController.close);
    final authController = StreamController<AuthUser?>();
    addTearDown(authController.close);

    await pumpApp(
      tester,
      authStream: authController.stream,
      positionStream: positionController.stream,
    );

    authController.add(null);
    await pumpUntilFound(tester, find.byType(LoginScreen));
    expect(find.byType(LoginScreen), findsOneWidget);

    authController.add(const AuthUser(uid: 'u', email: 'e@e.com'));
    await pumpUntilFound(tester, find.byType(MapScreen));
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('Firebase 초기화 에러 시 스플래시에 복구 UI가 뜨고 로그인 화면이 뜨지 않는다',
      (tester) async {
    // 인증 스트림 에러(초기화 실패 상당)를 주입한다. Stream.error는 즉시
    // 완료되므로 broadcast일 필요가 없다.
    await pumpApp(
      tester,
      authStream: Stream<AuthUser?>.error(Exception('init failed')),
    );
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('splash_retry_button')),
    );

    // 복구 UI가 뜨고, 로그인 화면으로 새어나가지 않는다.
    expect(find.byKey(const ValueKey('splash_retry_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash_error_text')), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
