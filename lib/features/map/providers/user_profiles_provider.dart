import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../models/nearby_user.dart';

/// Firestore 접근 실패(미생성/오프라인) 시 사용할 기본 테스트 사용자 5명.
///
/// 디버그 빌드에서 `users` 컬렉션이 비어 있으면 이 목록을 시드로 쓴다.
const List<NearbyUser> defaultNearbyUsers = [
  NearbyUser(id: 'user1', name: '김민준', age: 27, gender: 'm'),
  NearbyUser(id: 'user2', name: '이서연', age: 25, gender: 'f'),
  NearbyUser(id: 'user3', name: '박지훈', age: 29, gender: 'm'),
  NearbyUser(id: 'user4', name: '최수아', age: 24, gender: 'f'),
  NearbyUser(id: 'user5', name: '정도윤', age: 31, gender: 'm'),
];

/// Firestore `users` 컬렉션 접근을 감싸는 소형 repository.
///
/// provider override로 통째로 교체할 수 있어, 테스트가 실제 Firestore에 닿지
/// 않도록 한다.
class UserProfileRepository {
  const UserProfileRepository();

  /// 프로필 목록을 로드한다.
  ///
  /// 컬렉션이 비어 있으면(디버그 빌드) 기본 목록을 시드한 뒤 반환한다.
  /// 개별 문서 파싱이 실패하면(타입 불일치 등) 그 문서만 건너뛰고, 유효 문서가
  /// 하나도 없으면 기본 목록으로 fallback한다. Firestore 접근 자체의 예외는
  /// 여기서 잡지 않고 상위 provider의 fallback에 맡긴다.
  Future<List<NearbyUser>> loadProfiles() async {
    final firestore = FirebaseFirestore.instance;
    final collection = firestore.collection('users');
    // 회원가입으로 생긴 실제 사용자 문서(sim 없음)가 지도 위 가짜 마커로
    // 나타나지 않도록 sim==true 문서만 로드한다. 쿼리 결과가 비면 기존 로직대로
    // 시드하며 같은 id로 set하므로 sim 없는 기존 문서도 자동 마이그레이션된다.
    final snapshot = await collection.where('sim', isEqualTo: true).get();

    if (snapshot.docs.isEmpty) {
      if (kDebugMode) {
        final batch = firestore.batch();
        for (final user in defaultNearbyUsers) {
          batch.set(collection.doc(user.id), {...user.toMap(), 'sim': true});
        }
        await batch.commit();
      }
      return defaultNearbyUsers;
    }

    final profiles = <NearbyUser>[];
    for (final doc in snapshot.docs) {
      try {
        profiles.add(NearbyUser.fromFirestore(doc.id, doc.data()));
      } catch (e) {
        debugPrint('프로필 문서 ${doc.id} 파싱 실패 — 건너뜁니다: $e');
      }
    }
    // 전부 파싱에 실패하면 빈 화면 대신 기본 목록으로 대체한다.
    return profiles.isEmpty ? defaultNearbyUsers : profiles;
  }
}

/// 프로필 repository provider. 테스트에서 fake로 override한다.
final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => const UserProfileRepository(),
);

/// 주변 사용자 프로필 목록 provider.
///
/// Firebase 초기화나 Firestore 접근이 실패해도 예외를 화면까지 전파하지 않고
/// [defaultNearbyUsers]로 fallback한다 — 프로필은 부가 정보라 없어도 지도는
/// 동작해야 한다.
final userProfilesProvider = FutureProvider<List<NearbyUser>>((ref) async {
  try {
    await ref.watch(firebaseInitProvider.future);
    final repository = ref.watch(userProfileRepositoryProvider);
    return await repository.loadProfiles();
  } catch (e) {
    debugPrint('프로필 로드 실패 — 기본 사용자 목록으로 대체합니다: $e');
    return defaultNearbyUsers;
  }
});
