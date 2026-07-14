import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/core/router/app_router.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:gps_meeting_app/features/profile/providers/my_profile_provider.dart';
import 'package:gps_meeting_app/features/profile/screens/my_page_screen.dart';

void main() {
  /// override한 프로필로 MyPageScreen을 직접 펌프한다.
  /// requireLogin은 false로 둬 auth 의존을 끊는다.
  Future<void> pumpMyPage(WidgetTester tester, NearbyUser profile) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          requireLoginProvider.overrideWithValue(false),
          myProfileProvider.overrideWithValue(profile),
        ],
        child: const MaterialApp(home: MyPageScreen()),
      ),
    );
  }

  testWidgets('프로필 헤더에 이름·나이·성별(남)이 렌더된다', (tester) async {
    await pumpMyPage(
      tester,
      const NearbyUser(id: 'me', name: '김철수', age: 28, gender: 'm'),
    );

    expect(find.text('김철수'), findsOneWidget);
    expect(find.text('28세 · 남'), findsOneWidget);
  });

  testWidgets('gender가 f면 성별 라벨이 여로 표시된다', (tester) async {
    await pumpMyPage(
      tester,
      const NearbyUser(id: 'me', name: '이영희', age: 25, gender: 'f'),
    );

    expect(find.text('이영희'), findsOneWidget);
    expect(find.text('25세 · 여'), findsOneWidget);
  });
}
