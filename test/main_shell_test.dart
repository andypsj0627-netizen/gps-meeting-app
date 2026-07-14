import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gps_meeting_app/core/router/app_router.dart';
import 'package:gps_meeting_app/features/auth/models/auth_user.dart';
import 'package:gps_meeting_app/features/auth/providers/auth_providers.dart';
import 'package:gps_meeting_app/features/auth/services/auth_repository.dart';
import 'package:gps_meeting_app/features/chat/screens/chat_list_screen.dart';
import 'package:gps_meeting_app/features/encounters/screens/encounters_screen.dart';
import 'package:gps_meeting_app/features/home/screens/home_screen.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:gps_meeting_app/features/map/providers/location_provider.dart';
import 'package:gps_meeting_app/features/map/providers/nearby_users_provider.dart';
import 'package:gps_meeting_app/features/map/providers/user_profiles_provider.dart';
import 'package:gps_meeting_app/features/map/screens/map_screen.dart';
import 'package:gps_meeting_app/features/profile/screens/my_page_screen.dart';
import 'package:gps_meeting_app/main.dart';

import 'helpers/location_test_helpers.dart';

/// signOut 호출을 기록하는 fake 인증 repository.
class FakeAuthRepository implements AuthRepository {
  int signOutCallCount = 0;

  @override
  Stream<AuthUser?> authStateChanges() =>
      Stream.value(const AuthUser(uid: 'u', email: 'e@e.com'));

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }
}

void main() {
  testWidgets('기본 탭이 지도다', (tester) async {
    final controller = StreamController<Position>.broadcast();
    addTearDown(controller.close);
    await pumpApp(tester, requireLogin: false, positionStream: controller.stream);
    await pumpUntilFound(tester, find.byType(NavigationBar));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(MapScreen), findsOneWidget);

    controller.add(fakePosition(37.5, 127.0));
    await pumpUntilFound(tester, find.byType(FlutterMap));
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('각 탭으로 전환된다', (tester) async {
    final controller = StreamController<Position>.broadcast();
    addTearDown(controller.close);
    await pumpApp(tester, requireLogin: false, positionStream: controller.stream);
    await pumpUntilFound(tester, find.byType(NavigationBar));

    NavigationBar navBar() => tester.widget<NavigationBar>(
          find.byType(NavigationBar),
        );

    // 홈(index 0)
    await tester.tap(find.byIcon(Icons.home));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(navBar().selectedIndex, 0);

    // 스침(index 2)
    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(EncountersScreen), findsOneWidget);
    expect(navBar().selectedIndex, 2);

    // 대화(index 3)
    await tester.tap(find.byIcon(Icons.chat_bubble));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ChatListScreen), findsOneWidget);
    expect(navBar().selectedIndex, 3);

    // 마이(index 4)
    await tester.tap(find.byIcon(Icons.person));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MyPageScreen), findsOneWidget);
    expect(navBar().selectedIndex, 4);
  });

  testWidgets('지도 상태가 탭 전환에도 보존된다', (tester) async {
    final controller = StreamController<Position>.broadcast();
    addTearDown(controller.close);
    await pumpApp(tester, requireLogin: false, positionStream: controller.stream);
    await pumpUntilFound(tester, find.byType(NavigationBar));

    controller.add(fakePosition(37.5, 127.0));
    await pumpUntilFound(tester, find.byType(FlutterMap));
    final stateBefore = tester.state(find.byType(MapScreen));

    // 마이 탭으로 이동
    await tester.tap(find.byIcon(Icons.person));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 다시 지도 탭으로
    await tester.tap(find.byIcon(Icons.map));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // indexedStack이라 같은 State가 유지된다.
    expect(tester.state(find.byType(MapScreen)), same(stateBefore));
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('우회 모드에서는 로그아웃 버튼이 없다', (tester) async {
    final controller = StreamController<Position>.broadcast();
    addTearDown(controller.close);
    await pumpApp(tester, requireLogin: false, positionStream: controller.stream);
    await pumpUntilFound(tester, find.byType(NavigationBar));

    await tester.tap(find.byIcon(Icons.person));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('logout_button')), findsNothing);
  });

  testWidgets('인증 모드에서 로그아웃 버튼이 보이고 탭하면 signOut이 호출된다',
      (tester) async {
    final fakeRepo = FakeAuthRepository();
    final controller = StreamController<Position>.broadcast();
    addTearDown(controller.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requireLoginProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(fakeRepo),
          authStateChangesProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(uid: 'u', email: 'e@e.com')),
          ),
          locationServiceProvider.overrideWithValue(
            FakeLocationService(controller.stream),
          ),
          nearbyUsersServiceProvider.overrideWithValue(
            ControlledNearbyUsersService(const Stream<List<NearbyUser>>.empty()),
          ),
          userProfilesProvider.overrideWith((ref) async => defaultNearbyUsers),
        ],
        child: const MyApp(),
      ),
    );
    await pumpUntilFound(tester, find.byType(NavigationBar));

    await tester.tap(find.byIcon(Icons.person));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('logout_button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('logout_button')));
    await tester.pump();
    expect(fakeRepo.signOutCallCount, 1);
  });
}
