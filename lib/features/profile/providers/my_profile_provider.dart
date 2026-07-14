import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../map/models/nearby_user.dart';

/// 내 프로필 provider.
///
/// Fake 프로필 — 프로필 화면 작업에서 Firestore users/{uid} 로드로 교체 예정.
/// 마이 탭 헤더가 이 값을 watch해 이름/나이/성별을 렌더한다.
final myProfileProvider = Provider<NearbyUser>(
  (ref) => const NearbyUser(id: 'me', name: '김철수', age: 28, gender: 'm'),
);
