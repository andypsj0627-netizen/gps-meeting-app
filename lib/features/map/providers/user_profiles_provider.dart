import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../models/nearby_user.dart';

/// Firestore 접근 실패(미생성/오프라인) 시 사용할 기본 테스트 사용자 10명.
///
/// 디버그 빌드에서 이 목록 중 `users` 컬렉션에 없는 인물을 시드로 채운다.
const List<NearbyUser> defaultNearbyUsers = [
  NearbyUser(id: 'user1', name: '김민준', age: 27, gender: 'm'),
  NearbyUser(id: 'user2', name: '이서연', age: 25, gender: 'f'),
  NearbyUser(id: 'user3', name: '박지훈', age: 29, gender: 'm'),
  NearbyUser(id: 'user4', name: '최수아', age: 24, gender: 'f'),
  NearbyUser(id: 'user5', name: '정도윤', age: 31, gender: 'm'),
  NearbyUser(id: 'user6', name: '강하은', age: 26, gender: 'f'),
  NearbyUser(id: 'user7', name: '조은우', age: 28, gender: 'm'),
  NearbyUser(id: 'user8', name: '윤지민', age: 23, gender: 'f'),
  NearbyUser(id: 'user9', name: '임서준', age: 30, gender: 'm'),
  NearbyUser(id: 'user10', name: '한예린', age: 22, gender: 'f'),
];

/// Firestore `users` 컬렉션 접근을 감싸는 소형 repository.
///
/// provider override로 통째로 교체할 수 있어, 테스트가 실제 Firestore에 닿지
/// 않도록 한다.
class UserProfileRepository {
  const UserProfileRepository();

  /// 프로필 목록을 로드한다.
  ///
  /// 디버그 빌드에서는 로드된 문서에 없는 기본 인물을 항상 시드해 보충한다
  /// (일부만 시드된 상태에서 나머지가 누락되지 않도록). 개별 문서 파싱이
  /// 실패하면(타입 불일치 등) 그 문서만 건너뛰고, 유효 문서가 하나도 없으면
  /// 기본 목록으로 fallback한다. Firestore 접근 자체의 예외는 여기서 잡지 않고
  /// 상위 provider의 fallback에 맡긴다.
  Future<List<NearbyUser>> loadProfiles() async {
    final firestore = FirebaseFirestore.instance;
    final collection = firestore.collection('users');
    // 회원가입으로 생긴 실제 사용자 문서(sim 없음)가 지도 위 가짜 마커로
    // 나타나지 않도록 sim==true 문서만 로드한다.
    final snapshot = await collection.where('sim', isEqualTo: true).get();

    final profiles = <NearbyUser>[];
    for (final doc in snapshot.docs) {
      try {
        profiles.add(NearbyUser.fromFirestore(doc.id, doc.data()));
      } catch (e) {
        debugPrint('프로필 문서 ${doc.id} 파싱 실패 — 건너뜁니다: $e');
      }
    }

    // 이미 로드된 id를 제외하고, 기본 목록 중 누락된 인물만 추린다.
    final loadedIds = {for (final p in profiles) p.id};
    final missing =
        defaultNearbyUsers.where((u) => !loadedIds.contains(u.id)).toList();

    // 디버그 빌드에서는 누락된 기본 인물을 시드해 화면과 Firestore를 일치시킨다.
    // batch.set은 id별 멱등이므로 이미 있는 문서를 덮어써도 안전하다.
    if (kDebugMode && missing.isNotEmpty) {
      final batch = firestore.batch();
      for (final user in missing) {
        batch.set(collection.doc(user.id), {...user.toMap(), 'sim': true});
      }
      await batch.commit();
      profiles.addAll(missing);
    }

    // 유효 프로필이 하나도 없으면(파싱 전멸 등) 빈 화면 대신 기본 목록으로 대체한다.
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
