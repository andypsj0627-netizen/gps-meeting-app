import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/core/firebase/firebase_providers.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';
import 'package:gps_meeting_app/features/map/providers/user_profiles_provider.dart';

/// 지정한 결과/예외를 내는 fake repository.
class _FakeRepo extends UserProfileRepository {
  _FakeRepo({this.result, this.error});

  final List<NearbyUser>? result;
  final Object? error;

  @override
  Future<List<NearbyUser>> loadProfiles() async {
    if (error != null) throw error!;
    return result!;
  }
}

void main() {
  group('userProfilesProvider', () {
    test('repository가 반환한 프로필을 그대로 전달한다', () async {
      const profiles = [NearbyUser(id: 'x', name: '테스트', age: 1, gender: 'm')];
      final container = ProviderContainer(
        overrides: [
          firebaseInitProvider.overrideWith((ref) async {}),
          userProfileRepositoryProvider
              .overrideWithValue(_FakeRepo(result: profiles)),
        ],
      );
      addTearDown(container.dispose);

      final loaded = await container.read(userProfilesProvider.future);
      expect(loaded, profiles);
    });

    test('Firestore 접근 실패 시 기본 목록으로 fallback하고 예외를 전파하지 않는다',
        () async {
      final container = ProviderContainer(
        overrides: [
          firebaseInitProvider.overrideWith((ref) async {}),
          userProfileRepositoryProvider
              .overrideWithValue(_FakeRepo(error: Exception('오프라인'))),
        ],
      );
      addTearDown(container.dispose);

      final loaded = await container.read(userProfilesProvider.future);
      expect(loaded, defaultNearbyUsers);
    });
  });
}
